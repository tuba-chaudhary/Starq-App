require('dotenv').config();
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const { createPool } = require('./db');
const { migrate } = require('./migrate');
const { createRouter } = require('./routes');
const { razorpayConfigured } = require('./lib/razorpayClient');

async function main() {
  if (!process.env.JWT_ACCESS_SECRET || !process.env.JWT_REFRESH_SECRET) {
    throw new Error('JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must be set');
  }
  const pool = createPool();
  await migrate(pool);

  const app = express();
  app.use(cors());
  const { router, verifyAndConfirm, confirmCapturedPayment } = createRouter(pool);

  app.post(
    '/api/v1/payments/webhook',
    express.raw({ type: 'application/json' }),
    async (req, res) => {
      try {
        const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
        if (!secret) {
          return res.status(503).json({ success: false, message: 'RAZORPAY_WEBHOOK_SECRET is not configured' });
        }
        const signature = req.headers['x-razorpay-signature'];
        const body = req.body.toString('utf8');
        const expected = crypto.createHmac('sha256', secret).update(body).digest('hex');
        if (expected !== signature) {
          return res.status(400).json({ success: false, message: 'Invalid webhook signature' });
        }
        const event = JSON.parse(body);
        const eventId = event.payload?.payment?.entity?.id
          ? `${event.event}:${event.payload.payment.entity.id}`
          : `${event.event}:${event.created_at}`;
        const existing = await pool.query('SELECT id FROM payment_events WHERE event_id = $1', [eventId]);
        if (existing.rows.length) {
          return res.json({ success: true, duplicate: true });
        }
        await pool.query(
          `INSERT INTO payment_events (event_id, event_type, payload, is_processed)
           VALUES ($1,$2,$3,false)`,
          [eventId, event.event, event],
        );
        if (event.event === 'payment.captured' || event.event === 'order.paid') {
          const entity = event.payload.payment?.entity || {};
          const orderId = entity.order_id;
          const paymentId = entity.id;
          if (orderId && paymentId && (entity.status === 'captured' || event.event === 'order.paid')) {
            await confirmCapturedPayment(orderId, paymentId);
          }
        }
        if (event.event === 'payment.failed') {
          const entity = event.payload.payment?.entity || {};
          await pool.query(
            `UPDATE payments SET status = 'failed', razorpay_payment_id = $1, updated_at = NOW()
             WHERE razorpay_order_id = $2 AND status <> 'success'`,
            [entity.id, entity.order_id],
          );
          const pay = await pool.query('SELECT booking_id FROM payments WHERE razorpay_order_id = $1', [entity.order_id]);
          if (pay.rows[0]) {
            await pool.query(
              `UPDATE bookings SET status = 'PAYMENT_FAILED', updated_at = NOW()
               WHERE id = $1 AND status IN ('PENDING_PAYMENT','PAYMENT_PROCESSING')`,
              [pay.rows[0].booking_id],
            );
          }
        }
        await pool.query('UPDATE payment_events SET is_processed = true, processed_at = NOW() WHERE event_id = $1', [eventId]);
        res.json({ success: true });
      } catch (e) {
        console.error('webhook error');
        res.status(500).json({ success: false, message: 'Webhook processing failed' });
      }
    },
  );

  app.use(express.json({ limit: '2mb' }));
  app.use(express.urlencoded({ extended: true }));
  app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
  app.use('/public', express.static(path.join(__dirname, '../public')));

  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      razorpay_configured: razorpayConfigured(),
      service: 'starq-backend',
    });
  });

  app.use('/api/v1', router);

  app.get('/checkout/:bookingId', async (req, res) => {
    const html = fs.readFileSync(path.join(__dirname, '../public/checkout.html'), 'utf8');
    res.type('html').send(html);
  });

  app.get('/admin', (_req, res) => {
    res.sendFile(path.join(__dirname, '../public/admin.html'));
  });

  app.get('/partner', (_req, res) => {
    res.sendFile(path.join(__dirname, '../public/partner.html'));
  });

  app.post('/api/v1/payments/checkout-verify', async (req, res) => {
    try {
      const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body || {};
      const booking = await verifyAndConfirm({
        orderId: razorpay_order_id,
        paymentId: razorpay_payment_id,
        signature: razorpay_signature,
        userId: null,
      });
      res.json({ success: true, data: booking });
    } catch (e) {
      res.status(e.status || 400).json({ success: false, message: e.message });
    }
  });

  app.use((err, _req, res, _next) => {
    const status = err.status || 500;
    const message = status === 500 ? 'Internal server error' : err.message;
    if (status === 500) console.error(err);
    res.status(status).json({ success: false, message, code: err.code });
  });

  const port = Number(process.env.PORT || 3000);
  app.listen(port, () => {
    console.log(`STARQ API listening on ${port}`);
    if (!razorpayConfigured()) {
      console.log('Razorpay credentials are not set. Orders will return 503 until RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET are provided.');
    }
  });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
