const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const express = require('express');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const { v4: uuid } = require('uuid');
const { authRequired, wrap, signAccess, signRefresh, hashToken, publicUser } = require('./middleware');
const { computeQuote, rupeesToPaise } = require('./lib/pricing');
const { assertTransition, isTrackingActive } = require('./lib/stateMachine');
const { getClient, razorpayConfigured } = require('./lib/razorpayClient');

const uploadDir = path.join(__dirname, '../uploads');
fs.mkdirSync(uploadDir, { recursive: true });
const upload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, uploadDir),
    filename: (_req, file, cb) => cb(null, `${uuid()}${path.extname(file.originalname || '.jpg')}`),
  }),
  limits: { fileSize: 8 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (!String(file.mimetype || '').startsWith('image/')) {
      return cb(new Error('Only image uploads are allowed'));
    }
    cb(null, true);
  },
});

function createRouter(pool) {
  const router = express.Router();

  async function notify(userId, title, body) {
    await pool.query(
      'INSERT INTO notifications (user_id, title, body) VALUES ($1,$2,$3)',
      [userId, title, body],
    );
  }

  async function transitionBooking(client, booking, toStatus, userId, notes) {
    assertTransition(booking.status, toStatus);
    await client.query(
      `UPDATE bookings SET status = $1, updated_at = NOW() WHERE id = $2`,
      [toStatus, booking.id],
    );
    await client.query(
      `INSERT INTO booking_status_history (booking_id, from_status, to_status, changed_by_user_id, notes)
       VALUES ($1,$2,$3,$4,$5)`,
      [booking.id, booking.status, toStatus, userId || null, notes || null],
    );
    booking.status = toStatus;
  }

  async function currentPoints(userId) {
    const r = await pool.query(
      'SELECT balance_after FROM points_ledger WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1',
      [userId],
    );
    return r.rows[0]?.balance_after || 0;
  }

  async function addPoints(client, userId, bookingId, delta, description) {
    const cur = await client.query(
      'SELECT balance_after FROM points_ledger WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1',
      [userId],
    );
    const next = (cur.rows[0]?.balance_after || 0) + delta;
    await client.query(
      `INSERT INTO points_ledger (user_id, booking_id, points_delta, balance_after, description)
       VALUES ($1,$2,$3,$4,$5)`,
      [userId, bookingId, delta, next, description],
    );
    return next;
  }

  async function hydrateBooking(row) {
    const [vehicle, service, address, addons, partner, history] = await Promise.all([
      pool.query('SELECT * FROM vehicles WHERE id = $1', [row.vehicle_id]),
      pool.query('SELECT * FROM services WHERE id = $1', [row.service_id]),
      pool.query('SELECT * FROM addresses WHERE id = $1', [row.address_id]),
      pool.query('SELECT * FROM booking_addons WHERE booking_id = $1', [row.id]),
      row.partner_id
        ? pool.query(
            `SELECT p.id, u.full_name, u.phone, p.rating, p.total_completed_jobs, u.avatar_url
             FROM partners p JOIN users u ON u.id = p.user_id WHERE p.id = $1`,
            [row.partner_id],
          )
        : Promise.resolve({ rows: [] }),
      pool.query(
        'SELECT from_status, to_status, notes, created_at FROM booking_status_history WHERE booking_id = $1 ORDER BY created_at',
        [row.id],
      ),
    ]);
    const svc = service.rows[0];
    const inclusions = {};
    if (svc) {
      const feats = await pool.query(
        'SELECT section_name, feature_text FROM service_features WHERE service_id = $1 ORDER BY sort_order',
        [svc.id],
      );
      for (const f of feats.rows) {
        inclusions[f.section_name || 'Included'] = inclusions[f.section_name || 'Included'] || [];
        inclusions[f.section_name || 'Included'].push(f.feature_text);
      }
    }
    return {
      id: row.id,
      booking_number: row.booking_number,
      customer_id: row.customer_id,
      status: row.status,
      scheduled_date: row.scheduled_date,
      scheduled_time_slot: row.scheduled_time_slot,
      base_service_amount: Number(row.base_service_amount),
      add_ons_amount: Number(row.add_ons_amount),
      convenience_fee: Number(row.convenience_fee),
      tax_amount: Number(row.tax_amount),
      discount_amount: Number(row.discount_amount),
      final_total_amount: Number(row.final_total_amount),
      points_awarded: row.points_awarded,
      created_at: row.created_at,
      addons: addons.rows,
      status_history: history.rows,
      vehicle: vehicle.rows[0] || null,
      service: svc ? { ...svc, inclusions, base_price: Number(svc.base_price) } : null,
      address: address.rows[0] || null,
      partner: partner.rows[0]
        ? {
            id: partner.rows[0].id,
            name: partner.rows[0].full_name,
            full_name: partner.rows[0].full_name,
            phone: partner.rows[0].phone,
            rating: Number(partner.rows[0].rating),
            completed_jobs: partner.rows[0].total_completed_jobs,
            avatar_url: partner.rows[0].avatar_url,
          }
        : null,
    };
  }

  async function issueTokens(resUser) {
    const access = signAccess(resUser);
    const refresh = signRefresh(resUser);
    const decoded = require('jsonwebtoken').decode(refresh);
    await pool.query(
      'INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1,$2,to_timestamp($3))',
      [resUser.id, hashToken(refresh), decoded.exp],
    );
    return { access_token: access, refresh_token: refresh, user: publicUser(resUser) };
  }

  // ---------- Auth ----------
  router.post('/auth/register', wrap(async (req, res) => {
    const { full_name, email, phone, password } = req.body || {};
    if (!full_name || !email || !phone || !password) {
      return res.status(422).json({ success: false, message: 'Name, email, phone and password are required' });
    }
    const cleaned = String(phone).replace(/\D/g, '').slice(-10);
    if (cleaned.length !== 10) {
      return res.status(422).json({ success: false, message: 'Please enter a valid 10-digit mobile number' });
    }
    if (String(password).length < 6) {
      return res.status(422).json({ success: false, message: 'Password must be at least 6 characters' });
    }
    const hash = await bcrypt.hash(password, 10);
    try {
      const r = await pool.query(
        `INSERT INTO users (phone, email, password_hash, full_name, role)
         VALUES ($1,$2,$3,$4,'customer') RETURNING *`,
        [cleaned, String(email).toLowerCase().trim(), hash, full_name.trim()],
      );
      const tokens = await issueTokens(r.rows[0]);
      res.status(201).json({ success: true, data: tokens });
    } catch (e) {
      if (e.code === '23505') {
        return res.status(422).json({ success: false, message: 'Email or phone already registered' });
      }
      throw e;
    }
  }));

  router.post('/auth/login', wrap(async (req, res) => {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(422).json({ success: false, message: 'Email and password are required' });
    }
    const r = await pool.query('SELECT * FROM users WHERE email = $1 AND is_active = true', [String(email).toLowerCase().trim()]);
    if (!r.rows.length || !(await bcrypt.compare(password, r.rows[0].password_hash))) {
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    }
    const tokens = await issueTokens(r.rows[0]);
    res.json({ success: true, data: tokens });
  }));

  router.post('/auth/otp/send', wrap(async (_req, res) => {
    return res.status(503).json({
      success: false,
      message: 'SMS OTP is not configured. Set SMS_PROVIDER_API_KEY. Email/password login is available.',
    });
  }));

  router.post('/auth/otp/verify', wrap(async (_req, res) => {
    return res.status(503).json({
      success: false,
      message: 'SMS OTP is not configured. Email/password login is available.',
    });
  }));

  router.post('/auth/logout', authRequired(), wrap(async (req, res) => {
    const { refresh_token } = req.body || {};
    if (refresh_token) {
      await pool.query(
        'UPDATE refresh_tokens SET revoked = true WHERE user_id = $1 AND token_hash = $2',
        [req.user.sub, hashToken(refresh_token)],
      );
    } else {
      await pool.query('UPDATE refresh_tokens SET revoked = true WHERE user_id = $1', [req.user.sub]);
    }
    res.json({ success: true, data: { logged_out: true } });
  }));

  router.post('/auth/refresh', wrap(async (req, res) => {
    const { refresh_token } = req.body || {};
    if (!refresh_token) return res.status(422).json({ success: false, message: 'refresh_token is required' });
    const jwt = require('jsonwebtoken');
    let payload;
    try {
      payload = jwt.verify(refresh_token, process.env.JWT_REFRESH_SECRET);
    } catch {
      return res.status(401).json({ success: false, message: 'Invalid refresh token' });
    }
    const stored = await pool.query(
      'SELECT * FROM refresh_tokens WHERE user_id = $1 AND token_hash = $2 AND revoked = false AND expires_at > NOW()',
      [payload.sub, hashToken(refresh_token)],
    );
    if (!stored.rows.length) return res.status(401).json({ success: false, message: 'Refresh token revoked' });
    const user = await pool.query('SELECT * FROM users WHERE id = $1', [payload.sub]);
    const tokens = await issueTokens(user.rows[0]);
    res.json({ success: true, data: tokens });
  }));

  router.get('/auth/me', authRequired(), wrap(async (req, res) => {
    const r = await pool.query('SELECT * FROM users WHERE id = $1', [req.user.sub]);
    res.json({ success: true, data: publicUser(r.rows[0]) });
  }));

  router.put('/auth/me', authRequired(), wrap(async (req, res) => {
    const { full_name, phone } = req.body || {};
    const r = await pool.query(
      `UPDATE users SET full_name = COALESCE($1, full_name), phone = COALESCE($2, phone), updated_at = NOW()
       WHERE id = $3 RETURNING *`,
      [full_name, phone, req.user.sub],
    );
    res.json({ success: true, data: publicUser(r.rows[0]) });
  }));

  // ---------- Catalog ----------
  router.get('/vehicle-types', wrap(async (_req, res) => {
    const r = await pool.query('SELECT * FROM vehicle_types ORDER BY sort_order');
    res.json({ success: true, data: r.rows });
  }));

  router.get('/services', wrap(async (req, res) => {
    const type = req.query.vehicle_type;
    const category = req.query.category;
    const params = [];
    let sql = 'SELECT * FROM services WHERE is_active = true';
    if (type) {
      params.push(type);
      sql += ` AND target_vehicle_type = $${params.length}`;
    }
    sql += ' ORDER BY sort_order';
    const r = await pool.query(sql, params);
    const out = [];
    for (const s of r.rows) {
      const feats = await pool.query(
        'SELECT section_name, feature_text FROM service_features WHERE service_id = $1 ORDER BY sort_order',
        [s.id],
      );
      const inclusions = {};
      for (const f of feats.rows) {
        inclusions[f.section_name || 'Included'] = inclusions[f.section_name || 'Included'] || [];
        inclusions[f.section_name || 'Included'].push(f.feature_text);
      }
      let price = Number(s.base_price);
      if (category) {
        const v = await pool.query(
          'SELECT price FROM service_variants WHERE service_id = $1 AND vehicle_category = $2',
          [s.id, category],
        );
        if (v.rows[0]) price = Number(v.rows[0].price);
      }
      out.push({ ...s, base_price: price, catalog_base_price: Number(s.base_price), inclusions });
    }
    res.json({ success: true, data: out });
  }));

  router.get('/services/:id', wrap(async (req, res) => {
    const r = await pool.query('SELECT * FROM services WHERE id = $1 OR slug = $1', [req.params.id]);
    if (!r.rows[0]) return res.status(404).json({ success: false, message: 'Service not found' });
    const s = r.rows[0];
    const feats = await pool.query(
      'SELECT section_name, feature_text FROM service_features WHERE service_id = $1 ORDER BY sort_order',
      [s.id],
    );
    const variants = await pool.query('SELECT vehicle_category, price FROM service_variants WHERE service_id = $1', [s.id]);
    const inclusions = {};
    for (const f of feats.rows) {
      inclusions[f.section_name || 'Included'] = inclusions[f.section_name || 'Included'] || [];
      inclusions[f.section_name || 'Included'].push(f.feature_text);
    }
    res.json({ success: true, data: { ...s, base_price: Number(s.base_price), inclusions, variants: variants.rows } });
  }));

  router.get('/addons', wrap(async (req, res) => {
    const category = req.query.category;
    const vehicleType = req.query.vehicle_type;
    const r = await pool.query('SELECT * FROM service_addons WHERE is_active = true');
    const out = [];
    for (const a of r.rows) {
      if (vehicleType && a.applicable_vehicle_type !== 'both' && a.applicable_vehicle_type !== vehicleType) continue;
      let price = null;
      if (category) {
        const p = await pool.query(
          'SELECT price FROM addon_category_prices WHERE addon_id = $1 AND vehicle_category = $2',
          [a.id, category],
        );
        if (!p.rows[0]) continue;
        price = Number(p.rows[0].price);
      }
      out.push({ ...a, price });
    }
    res.json({ success: true, data: out });
  }));

  router.get('/service-areas/check', wrap(async (req, res) => {
    const pincode = req.query.pincode;
    if (!pincode) return res.status(422).json({ success: false, message: 'pincode is required' });
    const r = await pool.query('SELECT * FROM service_areas WHERE pincode = $1 AND is_active = true', [pincode]);
    res.json({ success: true, data: { serviceable: r.rows.length > 0, area: r.rows[0] || null } });
  }));

  router.get('/consents/current', wrap(async (_req, res) => {
    const r = await pool.query('SELECT * FROM consent_versions WHERE is_active = true ORDER BY created_at DESC LIMIT 1');
    res.json({ success: true, data: r.rows[0] });
  }));

  // ---------- Vehicles ----------
  router.get('/vehicles', authRequired('customer', 'admin'), wrap(async (req, res) => {
    const r = await pool.query('SELECT * FROM vehicles WHERE user_id = $1 ORDER BY is_primary DESC, created_at DESC', [req.user.sub]);
    res.json({ success: true, data: r.rows });
  }));

  router.post('/vehicles', authRequired('customer', 'admin'), wrap(async (req, res) => {
    const { category, brand, model, variant, registration_number, color, fuel_type, is_primary } = req.body || {};
    if (!category || !brand || !model || !registration_number) {
      return res.status(422).json({ success: false, message: 'category, brand, model and registration_number are required' });
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      if (is_primary) {
        await client.query('UPDATE vehicles SET is_primary = false WHERE user_id = $1', [req.user.sub]);
      }
      const count = await client.query('SELECT count(*)::int AS c FROM vehicles WHERE user_id = $1', [req.user.sub]);
      const primary = Boolean(is_primary) || count.rows[0].c === 0;
      const r = await client.query(
        `INSERT INTO vehicles (user_id, category, brand, model, variant, registration_number, color, fuel_type, is_primary)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
        [req.user.sub, category, brand, model, variant || null, String(registration_number).toUpperCase(), color || null, fuel_type || null, primary],
      );
      await client.query('COMMIT');
      res.status(201).json({ success: true, data: r.rows[0] });
    } catch (e) {
      await client.query('ROLLBACK');
      if (e.code === '23505') return res.status(422).json({ success: false, message: 'This registration number is already in your garage' });
      throw e;
    } finally {
      client.release();
    }
  }));

  router.put('/vehicles/:id', authRequired('customer', 'admin'), wrap(async (req, res) => {
    const existing = await pool.query('SELECT * FROM vehicles WHERE id = $1 AND user_id = $2', [req.params.id, req.user.sub]);
    if (!existing.rows[0]) return res.status(404).json({ success: false, message: 'Vehicle not found' });
    const v = existing.rows[0];
    const b = req.body || {};
    const r = await pool.query(
      `UPDATE vehicles SET category=COALESCE($1,category), brand=COALESCE($2,brand), model=COALESCE($3,model),
       variant=COALESCE($4,variant), registration_number=COALESCE($5,registration_number), color=COALESCE($6,color),
       fuel_type=COALESCE($7,fuel_type), updated_at=NOW() WHERE id=$8 RETURNING *`,
      [b.category, b.brand, b.model, b.variant, b.registration_number ? String(b.registration_number).toUpperCase() : null, b.color, b.fuel_type, v.id],
    );
    res.json({ success: true, data: r.rows[0] });
  }));

  router.post('/vehicles/:id/primary', authRequired('customer', 'admin'), wrap(async (req, res) => {
    await pool.query('UPDATE vehicles SET is_primary = false WHERE user_id = $1', [req.user.sub]);
    const r = await pool.query(
      'UPDATE vehicles SET is_primary = true WHERE id = $1 AND user_id = $2 RETURNING *',
      [req.params.id, req.user.sub],
    );
    if (!r.rows[0]) return res.status(404).json({ success: false, message: 'Vehicle not found' });
    res.json({ success: true, data: r.rows[0] });
  }));

  router.delete('/vehicles/:id', authRequired('customer', 'admin'), wrap(async (req, res) => {
    const r = await pool.query('DELETE FROM vehicles WHERE id = $1 AND user_id = $2 RETURNING id', [req.params.id, req.user.sub]);
    if (!r.rows[0]) return res.status(404).json({ success: false, message: 'Vehicle not found' });
    res.json({ success: true, data: { id: r.rows[0].id } });
  }));

  // ---------- Addresses ----------
  router.get('/addresses', authRequired(), wrap(async (req, res) => {
    const r = await pool.query('SELECT * FROM addresses WHERE user_id = $1 ORDER BY is_default DESC, created_at DESC', [req.user.sub]);
    res.json({ success: true, data: r.rows });
  }));

  router.post('/addresses', authRequired(), wrap(async (req, res) => {
    const { label, address_line, landmark, city, state, pincode, latitude, longitude, is_default } = req.body || {};
    if (!address_line || !pincode || latitude == null || longitude == null) {
      return res.status(422).json({ success: false, message: 'address_line, pincode, latitude and longitude are required' });
    }
    const area = await pool.query('SELECT * FROM service_areas WHERE pincode = $1 AND is_active = true', [pincode]);
    if (!area.rows[0]) {
      return res.status(422).json({ success: false, message: 'STARQ does not currently service this pincode' });
    }
    if (is_default) await pool.query('UPDATE addresses SET is_default = false WHERE user_id = $1', [req.user.sub]);
    const count = await pool.query('SELECT count(*)::int AS c FROM addresses WHERE user_id = $1', [req.user.sub]);
    const r = await pool.query(
      `INSERT INTO addresses (user_id, label, address_line, landmark, city, state, pincode, latitude, longitude, is_default)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
      [req.user.sub, label || 'Home', address_line, landmark || null, city || 'Noida', state || 'Uttar Pradesh', pincode, latitude, longitude, Boolean(is_default) || count.rows[0].c === 0],
    );
    res.status(201).json({ success: true, data: r.rows[0] });
  }));

  router.delete('/addresses/:id', authRequired(), wrap(async (req, res) => {
    const r = await pool.query('DELETE FROM addresses WHERE id = $1 AND user_id = $2 RETURNING id', [req.params.id, req.user.sub]);
    if (!r.rows[0]) return res.status(404).json({ success: false, message: 'Address not found' });
    res.json({ success: true });
  }));

  // ---------- Slots / Quotes / Bookings ----------
  router.get('/bookings/available-slots', authRequired(), wrap(async (req, res) => {
    const date = req.query.date;
    const pincode = req.query.pincode;
    if (!date) return res.status(422).json({ success: false, message: 'date is required' });
    if (pincode) {
      const area = await pool.query('SELECT id FROM service_areas WHERE pincode = $1 AND is_active = true', [pincode]);
      if (!area.rows[0]) return res.json({ success: true, data: [] });
    }
    const slots = ['08:00 AM', '09:00 AM', '10:00 AM', '11:00 AM', '01:00 PM', '03:00 PM', '05:00 PM'];
    const now = new Date();
    const requested = new Date(`${date}T00:00:00`);
    const out = [];
    for (const slot of slots) {
      const booked = await pool.query(
        `SELECT count(*)::int AS c FROM bookings
         WHERE scheduled_date = $1 AND scheduled_time_slot = $2
           AND status NOT IN ('CANCELLED','PAYMENT_FAILED','REFUNDED','DRAFT')`,
        [date, slot],
      );
      const partners = await pool.query('SELECT count(*)::int AS c FROM partners WHERE is_online = true');
      const capacity = partners.rows[0].c || 1;
      let available = booked.rows[0].c < capacity;
      const match = slot.match(/(\d+):(\d+)\s*(AM|PM)/i);
      if (match) {
        let hour = Number(match[1]) % 12;
        if (match[3].toUpperCase() === 'PM') hour += 12;
        const slotTime = new Date(requested);
        slotTime.setHours(hour, Number(match[2]), 0, 0);
        if (slotTime.getTime() - now.getTime() < 2 * 60 * 60 * 1000) available = false;
      }
      out.push({ slot, available });
    }
    res.json({ success: true, data: out });
  }));

  router.post('/bookings/quote', authRequired('customer', 'admin'), wrap(async (req, res) => {
    const { vehicle_id, service_id, addon_ids, address_id, scheduled_date, scheduled_time_slot, consent_id } = req.body || {};
    if (!vehicle_id || !service_id || !address_id || !scheduled_date || !scheduled_time_slot || !consent_id) {
      return res.status(422).json({ success: false, message: 'vehicle_id, service_id, address_id, scheduled_date, scheduled_time_slot and consent_id are required' });
    }
    const consent = await pool.query(
      'SELECT * FROM consents WHERE id = $1 AND customer_id = $2 AND acknowledged = true',
      [consent_id, req.user.sub],
    );
    if (!consent.rows[0]) {
      return res.status(422).json({ success: false, message: 'Vehicle condition consent must be acknowledged before quoting' });
    }
    const vehicle = await pool.query('SELECT * FROM vehicles WHERE id = $1 AND user_id = $2', [vehicle_id, req.user.sub]);
    if (!vehicle.rows[0]) return res.status(404).json({ success: false, message: 'Vehicle not found' });
    const address = await pool.query('SELECT * FROM addresses WHERE id = $1 AND user_id = $2', [address_id, req.user.sub]);
    if (!address.rows[0]) return res.status(404).json({ success: false, message: 'Address not found' });
    const area = await pool.query('SELECT * FROM service_areas WHERE pincode = $1 AND is_active = true', [address.rows[0].pincode]);
    if (!area.rows[0]) return res.status(422).json({ success: false, message: 'Address is outside STARQ service areas' });
    const service = await pool.query('SELECT * FROM services WHERE id = $1 AND is_active = true', [service_id]);
    if (!service.rows[0]) return res.status(404).json({ success: false, message: 'Service not found' });
    const variant = await pool.query(
      'SELECT price FROM service_variants WHERE service_id = $1 AND vehicle_category = $2',
      [service_id, vehicle.rows[0].category],
    );
    if (!variant.rows[0]) return res.status(422).json({ success: false, message: 'No price for this vehicle category' });
    const ids = Array.isArray(addon_ids) ? addon_ids : [];
    const addonRows = [];
    const addonPrices = [];
    for (const id of ids) {
      const a = await pool.query(
        `SELECT sa.*, acp.price FROM service_addons sa
         JOIN addon_category_prices acp ON acp.addon_id = sa.id
         WHERE sa.id = $1 AND acp.vehicle_category = $2 AND sa.is_active = true`,
        [id, vehicle.rows[0].category],
      );
      if (!a.rows[0]) return res.status(422).json({ success: false, message: 'Invalid add-on for this vehicle' });
      addonRows.push(a.rows[0]);
      addonPrices.push(Number(a.rows[0].price));
    }
    const amounts = computeQuote({ basePrice: Number(variant.rows[0].price), addOnPrices: addonPrices });
    const token = uuid();
    const payload = {
      vehicle_id, service_id, addon_ids: ids, address_id, scheduled_date, scheduled_time_slot,
      consent_id,
      category: vehicle.rows[0].category,
      addons: addonRows.map((a) => ({ id: a.id, name: a.name, price: Number(a.price) })),
    };
    await pool.query(
      `INSERT INTO quotes (customer_id, token, payload, amounts, expires_at)
       VALUES ($1,$2,$3,$4, NOW() + INTERVAL '30 minutes')`,
      [req.user.sub, token, payload, amounts],
    );
    res.json({
      success: true,
      data: {
        ...amounts,
        quote_token: token,
        currency: 'INR',
        line_items: [
          { name: service.rows[0].name, amount: amounts.base_service_amount },
          ...addonRows.map((a) => ({ name: a.name, amount: Number(a.price) })),
        ],
      },
    });
  }));

  router.get('/bookings', authRequired(), wrap(async (req, res) => {
    const role = req.user.role;
    let sql = 'SELECT * FROM bookings WHERE 1=1';
    const params = [];
    if (role === 'customer') {
      params.push(req.user.sub);
      sql += ` AND customer_id = $${params.length}`;
    } else if (role === 'service_partner') {
      const p = await pool.query('SELECT id FROM partners WHERE user_id = $1', [req.user.sub]);
      if (!p.rows[0]) return res.json({ success: true, data: [] });
      params.push(p.rows[0].id);
      sql += ` AND partner_id = $${params.length}`;
    }
    if (req.query.status) {
      params.push(req.query.status);
      sql += ` AND status = $${params.length}`;
    }
    sql += ' ORDER BY created_at DESC';
    const r = await pool.query(sql, params);
    const data = [];
    for (const row of r.rows) data.push(await hydrateBooking(row));
    res.json({ success: true, data });
  }));

  router.get('/bookings/:id', authRequired(), wrap(async (req, res) => {
    const r = await pool.query('SELECT * FROM bookings WHERE id = $1', [req.params.id]);
    if (!r.rows[0]) return res.status(404).json({ success: false, message: 'Booking not found' });
    if (req.user.role === 'customer' && r.rows[0].customer_id !== req.user.sub) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    res.json({ success: true, data: await hydrateBooking(r.rows[0]) });
  }));

  router.post('/bookings/:id/cancel', authRequired(), wrap(async (req, res) => {
    const r = await pool.query('SELECT * FROM bookings WHERE id = $1', [req.params.id]);
    if (!r.rows[0]) return res.status(404).json({ success: false, message: 'Booking not found' });
    const booking = r.rows[0];
    if (req.user.role === 'customer' && booking.customer_id !== req.user.sub) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await transitionBooking(client, booking, 'CANCELLED', req.user.sub, req.body?.reason || 'Cancelled by user');
      if (['CONFIRMED', 'ASSIGNMENT_PENDING', 'PARTNER_ASSIGNED'].includes(booking.status) || true) {
        // paid bookings go to refund pending if payment succeeded
      }
      const pay = await client.query("SELECT * FROM payments WHERE booking_id = $1 AND status = 'success'", [booking.id]);
      if (pay.rows[0]) {
        booking.status = 'CANCELLED';
        await transitionBooking(client, booking, 'REFUND_PENDING', req.user.sub, 'Refund queued');
      }
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
    const fresh = await pool.query('SELECT * FROM bookings WHERE id = $1', [req.params.id]);
    res.json({ success: true, data: await hydrateBooking(fresh.rows[0]) });
  }));

  router.post('/bookings/:id/rebook', authRequired('customer', 'admin'), wrap(async (req, res) => {
    const r = await pool.query('SELECT * FROM bookings WHERE id = $1 AND customer_id = $2', [req.params.id, req.user.sub]);
    if (!r.rows[0]) return res.status(404).json({ success: false, message: 'Booking not found' });
    const addons = await pool.query('SELECT addon_id FROM booking_addons WHERE booking_id = $1', [req.params.id]);
    res.json({
      success: true,
      data: {
        vehicle_id: r.rows[0].vehicle_id,
        service_id: r.rows[0].service_id,
        address_id: r.rows[0].address_id,
        addon_ids: addons.rows.map((a) => a.addon_id),
        rebooked_from_id: r.rows[0].id,
      },
    });
  }));

  // ---------- Payments ----------
  async function createDraftFromQuote(userId, quoteToken) {
    const q = await pool.query(
      'SELECT * FROM quotes WHERE token = $1 AND customer_id = $2 AND consumed = false AND expires_at > NOW()',
      [quoteToken, userId],
    );
    if (!q.rows[0]) {
      const err = new Error('Quote expired or invalid. Please refresh booking summary.');
      err.status = 422;
      throw err;
    }
    const quote = q.rows[0];
    const p = quote.payload;
    const a = quote.amounts;
    const year = new Date().getFullYear();
    const seq = Math.floor(10000 + Math.random() * 89999);
    const bookingNumber = `STQ-${year}-${seq}`;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const b = await client.query(
        `INSERT INTO bookings (
          booking_number, customer_id, vehicle_id, service_id, address_id,
          scheduled_date, scheduled_time_slot, quote_snapshot,
          base_service_amount, add_ons_amount, convenience_fee, tax_amount, discount_amount,
          final_total_amount, points_awarded, status, rebooked_from_id
        ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,'PENDING_PAYMENT',$16) RETURNING *`,
        [
          bookingNumber, userId, p.vehicle_id, p.service_id, p.address_id,
          p.scheduled_date, p.scheduled_time_slot, { payload: p, amounts: a },
          a.base_service_amount, a.add_ons_amount, a.convenience_fee, a.tax_amount, a.discount_amount,
          a.final_total_amount, a.points_awarded, p.rebooked_from_id || null,
        ],
      );
      const booking = b.rows[0];
      await client.query(
        `INSERT INTO booking_status_history (booking_id, from_status, to_status, changed_by_user_id, notes)
         VALUES ($1,'DRAFT','PENDING_PAYMENT',$2,'Quote converted')`,
        [booking.id, userId],
      );
      await client.query(
        `INSERT INTO booking_items (booking_id, service_id, name_snapshot, amount) VALUES ($1,$2,$3,$4)`,
        [booking.id, p.service_id, 'Service', a.base_service_amount],
      );
      for (const addon of p.addons || []) {
        await client.query(
          `INSERT INTO booking_addons (booking_id, addon_id, name_snapshot, price_at_booking)
           VALUES ($1,$2,$3,$4)`,
          [booking.id, addon.id, addon.name, addon.price],
        );
      }
      await client.query('UPDATE quotes SET consumed = true WHERE id = $1', [quote.id]);
      if (p.consent_id) {
        await client.query('UPDATE consents SET booking_id = $1 WHERE id = $2 AND customer_id = $3', [booking.id, p.consent_id, userId]);
      }
      await client.query('COMMIT');
      return { booking, amounts: a };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  async function confirmPaidBooking(client, booking, userId, note) {
    if (booking.status === 'PENDING_PAYMENT' || booking.status === 'PAYMENT_FAILED') {
      await transitionBooking(client, { ...booking, status: booking.status }, 'PAYMENT_PROCESSING', userId, note);
      booking.status = 'PAYMENT_PROCESSING';
    }
    if (booking.status === 'PAYMENT_PROCESSING') {
      await transitionBooking(client, booking, 'CONFIRMED', userId, note);
      await transitionBooking(client, booking, 'ASSIGNMENT_PENDING', userId, 'Queueing partner assignment');
    }
    const assigned = await autoAssign(client, booking);
    return assigned;
  }

  async function autoAssign(client, booking) {
    const busy = await client.query(
      `SELECT partner_id FROM bookings
       WHERE partner_id IS NOT NULL
         AND status IN ('PARTNER_ASSIGNED','PARTNER_ON_THE_WAY','PARTNER_ARRIVED','SERVICE_STARTED','SERVICE_IN_PROGRESS')`,
    );
    const busyIds = busy.rows.map((r) => r.partner_id);
    const q = await client.query(
      `SELECT * FROM partners WHERE is_online = true AND is_available = true
       ${busyIds.length ? `AND id != ALL($1::uuid[])` : ''}
       ORDER BY rating DESC LIMIT 1`,
      busyIds.length ? [busyIds] : [],
    );
    if (!q.rows[0]) return null;
    await client.query('UPDATE bookings SET partner_id = $1, updated_at = NOW() WHERE id = $2', [q.rows[0].id, booking.id]);
    await transitionBooking(client, booking, 'PARTNER_ASSIGNED', null, 'Auto-assigned available partner');
    await client.query("UPDATE partners SET is_available = false, status = 'on_job' WHERE id = $1", [q.rows[0].id]);
    const partnerUser = await client.query('SELECT user_id FROM partners WHERE id = $1', [q.rows[0].id]);
    await notify(partnerUser.rows[0].user_id, 'New STARQ job', `Booking ${booking.booking_number} assigned to you`);
    await notify(booking.customer_id, 'Partner assigned', 'A STARQ partner has been assigned to your booking');
    return q.rows[0];
  }

  router.post('/payments/create-order', authRequired('customer', 'admin'), wrap(async (req, res) => {
    const { quote_token } = req.body || {};
    if (!quote_token) return res.status(422).json({ success: false, message: 'quote_token is required' });
    const client = getClient();
    const { booking, amounts } = await createDraftFromQuote(req.user.sub, quote_token);
    const order = await client.orders.create({
      amount: rupeesToPaise(amounts.final_total_amount),
      currency: 'INR',
      receipt: booking.booking_number,
      notes: { booking_id: booking.id },
    });
    await pool.query(
      `INSERT INTO payments (booking_id, razorpay_order_id, amount_in_paise, currency, status)
       VALUES ($1,$2,$3,'INR','pending')`,
      [booking.id, order.id, order.amount],
    );
    res.json({
      success: true,
      data: {
        booking_id: booking.id,
        booking_number: booking.booking_number,
        razorpay_order_id: order.id,
        amount: amounts.final_total_amount,
        amount_in_paise: order.amount,
        currency: 'INR',
        key_id: process.env.RAZORPAY_KEY_ID,
        checkout_url: `${process.env.APP_BASE_URL || 'http://localhost:3000'}/checkout/${booking.id}`,
      },
    });
  }));

  router.get('/payments/status/:bookingId', authRequired(), wrap(async (req, res) => {
    const pay = await pool.query('SELECT * FROM payments WHERE booking_id = $1 ORDER BY created_at DESC LIMIT 1', [req.params.bookingId]);
    const booking = await pool.query('SELECT * FROM bookings WHERE id = $1', [req.params.bookingId]);
    if (!booking.rows[0]) return res.status(404).json({ success: false, message: 'Booking not found' });
    if (req.user.role === 'customer' && booking.rows[0].customer_id !== req.user.sub) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    res.json({
      success: true,
      data: {
        payment: pay.rows[0] || null,
        booking: await hydrateBooking(booking.rows[0]),
      },
    });
  }));

  async function verifyAndConfirm({ orderId, paymentId, signature, userId }) {
    const secret = process.env.RAZORPAY_KEY_SECRET;
    const expected = crypto.createHmac('sha256', secret).update(`${orderId}|${paymentId}`).digest('hex');
    if (expected !== signature) {
      const err = new Error('Payment signature verification failed');
      err.status = 400;
      throw err;
    }
    const pay = await pool.query('SELECT * FROM payments WHERE razorpay_order_id = $1', [orderId]);
    if (!pay.rows[0]) {
      const err = new Error('Unknown Razorpay order');
      err.status = 404;
      throw err;
    }
    if (pay.rows[0].status === 'success') {
      const booking = await pool.query('SELECT * FROM bookings WHERE id = $1', [pay.rows[0].booking_id]);
      return hydrateBooking(booking.rows[0]);
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `UPDATE payments SET razorpay_payment_id=$1, razorpay_signature=$2, status='success', updated_at=NOW()
         WHERE id=$3`,
        [paymentId, signature, pay.rows[0].id],
      );
      const bookingRes = await client.query('SELECT * FROM bookings WHERE id = $1', [pay.rows[0].booking_id]);
      const booking = bookingRes.rows[0];
      await confirmPaidBooking(client, booking, userId, 'Razorpay signature verified');
      await client.query('COMMIT');
      const fresh = await pool.query('SELECT * FROM bookings WHERE id = $1', [booking.id]);
      return hydrateBooking(fresh.rows[0]);
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  router.post('/payments/verify', authRequired('customer', 'admin'), wrap(async (req, res) => {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body || {};
    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return res.status(422).json({ success: false, message: 'Razorpay order, payment and signature are required' });
    }
    const booking = await verifyAndConfirm({
      orderId: razorpay_order_id,
      paymentId: razorpay_payment_id,
      signature: razorpay_signature,
      userId: req.user.sub,
    });
    res.json({ success: true, data: booking });
  }));

  router.get('/payments/config', wrap(async (_req, res) => {
    res.json({
      success: true,
      data: {
        configured: razorpayConfigured(),
        key_id: razorpayConfigured() ? process.env.RAZORPAY_KEY_ID : null,
      },
    });
  }));

  // ---------- Tracking ----------
  router.get('/tracking/:id', authRequired(), wrap(async (req, res) => {
    const r = await pool.query('SELECT * FROM bookings WHERE id = $1', [req.params.id]);
    if (!r.rows[0]) return res.status(404).json({ success: false, message: 'Booking not found' });
    const booking = r.rows[0];
    if (req.user.role === 'customer' && booking.customer_id !== req.user.sub) {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    if (!isTrackingActive(booking.status)) {
      return res.json({
        success: true,
        data: { tracking_active: false, status: booking.status, location: null, booking: await hydrateBooking(booking) },
      });
    }
    const loc = await pool.query(
      'SELECT latitude, longitude, recorded_at FROM partner_locations WHERE partner_id = $1 ORDER BY recorded_at DESC LIMIT 1',
      [booking.partner_id],
    );
    res.json({
      success: true,
      data: {
        tracking_active: true,
        status: booking.status,
        location: loc.rows[0]
          ? { latitude: Number(loc.rows[0].latitude), longitude: Number(loc.rows[0].longitude), recorded_at: loc.rows[0].recorded_at }
          : null,
        booking: await hydrateBooking(booking),
      },
    });
  }));

  router.post('/partner/location', authRequired('service_partner', 'admin'), wrap(async (req, res) => {
    const { latitude, longitude, booking_id } = req.body || {};
    if (latitude == null || longitude == null) {
      return res.status(422).json({ success: false, message: 'latitude and longitude are required' });
    }
    const partner = await pool.query('SELECT id FROM partners WHERE user_id = $1', [req.user.sub]);
    if (!partner.rows[0]) return res.status(404).json({ success: false, message: 'Partner profile not found' });
    if (booking_id) {
      const b = await pool.query('SELECT * FROM bookings WHERE id = $1 AND partner_id = $2', [booking_id, partner.rows[0].id]);
      if (!b.rows[0] || !isTrackingActive(b.rows[0].status)) {
        return res.status(422).json({ success: false, message: 'Location can only be shared for an active assigned booking' });
      }
    }
    const r = await pool.query(
      `INSERT INTO partner_locations (partner_id, booking_id, latitude, longitude)
       VALUES ($1,$2,$3,$4) RETURNING *`,
      [partner.rows[0].id, booking_id || null, latitude, longitude],
    );
    res.json({ success: true, data: r.rows[0] });
  }));

  router.post('/partner/jobs/:id/status', authRequired('service_partner', 'admin'), wrap(async (req, res) => {
    const { status } = req.body || {};
    const partner = await pool.query('SELECT id FROM partners WHERE user_id = $1', [req.user.sub]);
    if (!partner.rows[0]) return res.status(404).json({ success: false, message: 'Partner profile not found' });
    const r = await pool.query('SELECT * FROM bookings WHERE id = $1 AND partner_id = $2', [req.params.id, partner.rows[0].id]);
    if (!r.rows[0]) return res.status(404).json({ success: false, message: 'Job not found' });
    if (status === 'SERVICE_STARTED') {
      const consented = await pool.query(
        'SELECT id FROM consents WHERE booking_id = $1 AND acknowledged = true LIMIT 1',
        [req.params.id],
      );
      if (!consented.rows[0]) {
        return res.status(422).json({
          success: false,
          message: 'Customer must acknowledge vehicle condition before service starts',
        });
      }
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const booking = r.rows[0];
      await transitionBooking(client, booking, status, req.user.sub, 'Partner status update');
      if (status === 'SERVICE_COMPLETED') {
        await transitionBooking(client, booking, 'CUSTOMER_FEEDBACK_PENDING', req.user.sub, 'Awaiting customer review');
        await addPoints(client, booking.customer_id, booking.id, booking.points_awarded, `Earned for ${booking.booking_number}`);
        await client.query("UPDATE partners SET is_available = true, status = 'available', total_completed_jobs = total_completed_jobs + 1 WHERE id = $1", [booking.partner_id]);
        await notify(booking.customer_id, 'Service completed', 'Please rate your STARQ wash');
      }
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
    const fresh = await pool.query('SELECT * FROM bookings WHERE id = $1', [req.params.id]);
    res.json({ success: true, data: await hydrateBooking(fresh.rows[0]) });
  }));

  // ---------- Inspection / consent ----------
  router.post('/consents', authRequired(), wrap(async (req, res) => {
    const { vehicle_id, existing_damage_notes, consent_version_id, acknowledged } = req.body || {};
    if (!acknowledged) return res.status(422).json({ success: false, message: 'Consent must be acknowledged' });
    const version = consent_version_id
      ? await pool.query('SELECT * FROM consent_versions WHERE id = $1', [consent_version_id])
      : await pool.query('SELECT * FROM consent_versions WHERE is_active = true ORDER BY created_at DESC LIMIT 1');
    if (!version.rows[0]) return res.status(404).json({ success: false, message: 'Consent version not found' });
    const r = await pool.query(
      `INSERT INTO consents (customer_id, consent_version_id, vehicle_id, acknowledged, existing_damage_notes, acknowledged_at)
       VALUES ($1,$2,$3,true,$4,NOW()) RETURNING *`,
      [req.user.sub, version.rows[0].id, vehicle_id || null, existing_damage_notes || null],
    );
    res.status(201).json({ success: true, data: { ...r.rows[0], version: version.rows[0] } });
  }));

  router.post('/consents/:id/photos', authRequired(), upload.single('photo'), wrap(async (req, res) => {
    if (!req.file) return res.status(422).json({ success: false, message: 'photo file is required' });
    const consent = await pool.query('SELECT * FROM consents WHERE id = $1 AND customer_id = $2', [req.params.id, req.user.sub]);
    if (!consent.rows[0]) return res.status(404).json({ success: false, message: 'Consent not found' });
    const url = `/uploads/${req.file.filename}`;
    const r = await pool.query(
      `INSERT INTO vehicle_condition_photos (consent_id, uploaded_by, photo_url, caption)
       VALUES ($1,$2,$3,$4) RETURNING *`,
      [req.params.id, req.user.sub, url, req.body?.caption || null],
    );
    res.status(201).json({ success: true, data: r.rows[0] });
  }));

  router.post('/inspections/:bookingId', authRequired('service_partner', 'admin'), upload.array('photos', 8), wrap(async (req, res) => {
    const { notes, pre_existing_damages_found } = req.body || {};
    const booking = await pool.query('SELECT * FROM bookings WHERE id = $1', [req.params.bookingId]);
    if (!booking.rows[0]) return res.status(404).json({ success: false, message: 'Booking not found' });
    const files = req.files || [];
    for (const f of files) {
      await pool.query(
        `INSERT INTO vehicle_condition_photos (booking_id, uploaded_by, photo_url, caption)
         VALUES ($1,$2,$3,'partner_inspection')`,
        [req.params.bookingId, req.user.sub, `/uploads/${f.filename}`],
      );
    }
    await pool.query(
      `INSERT INTO consents (booking_id, customer_id, consent_version_id, vehicle_id, existing_damage_notes)
       SELECT $1, customer_id, (SELECT id FROM consent_versions WHERE is_active LIMIT 1), vehicle_id, $2
       FROM bookings WHERE id = $1`,
      [req.params.bookingId, notes || null],
    );
    void pre_existing_damages_found;
    const photos = await pool.query('SELECT * FROM vehicle_condition_photos WHERE booking_id = $1', [req.params.bookingId]);
    await notify(booking.rows[0].customer_id, 'Inspection ready', 'Review pre-service vehicle photos and acknowledge to start');
    res.status(201).json({ success: true, data: { photos: photos.rows } });
  }));

  router.get('/inspections/:bookingId', authRequired(), wrap(async (req, res) => {
    const photos = await pool.query('SELECT * FROM vehicle_condition_photos WHERE booking_id = $1 ORDER BY created_at', [req.params.bookingId]);
    const consent = await pool.query('SELECT * FROM consents WHERE booking_id = $1 ORDER BY created_at DESC LIMIT 1', [req.params.bookingId]);
    res.json({ success: true, data: { photos: photos.rows, consent: consent.rows[0] || null } });
  }));

  router.post('/inspections/:bookingId/consent', authRequired('customer', 'admin'), wrap(async (req, res) => {
    const booking = await pool.query('SELECT * FROM bookings WHERE id = $1 AND customer_id = $2', [req.params.bookingId, req.user.sub]);
    if (!booking.rows[0]) return res.status(404).json({ success: false, message: 'Booking not found' });
    await pool.query(
      `UPDATE consents SET acknowledged = true, acknowledged_at = NOW() WHERE booking_id = $1`,
      [req.params.bookingId],
    );
    if (booking.rows[0].status === 'PARTNER_ARRIVED') {
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        await transitionBooking(client, booking.rows[0], 'SERVICE_STARTED', req.user.sub, 'Customer acknowledged inspection');
        await client.query('COMMIT');
      } catch (e) {
        await client.query('ROLLBACK');
        throw e;
      } finally {
        client.release();
      }
    }
    res.json({ success: true, data: { acknowledged: true } });
  }));

  // ---------- Reviews / rewards / notifications ----------
  router.post('/reviews', authRequired('customer', 'admin'), wrap(async (req, res) => {
    const { booking_id, rating, comment, tags } = req.body || {};
    if (!booking_id || !rating) return res.status(422).json({ success: false, message: 'booking_id and rating are required' });
    const booking = await pool.query('SELECT * FROM bookings WHERE id = $1 AND customer_id = $2', [booking_id, req.user.sub]);
    if (!booking.rows[0]) return res.status(404).json({ success: false, message: 'Booking not found' });
    if (!['SERVICE_COMPLETED', 'CUSTOMER_FEEDBACK_PENDING', 'COMPLETED'].includes(booking.rows[0].status)) {
      return res.status(422).json({ success: false, message: 'Review is only allowed after service completion' });
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const r = await client.query(
        `INSERT INTO reviews (booking_id, customer_id, partner_id, rating, tags, comment)
         VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
        [booking_id, req.user.sub, booking.rows[0].partner_id, rating, tags || [], comment || null],
      );
      if (booking.rows[0].status === 'CUSTOMER_FEEDBACK_PENDING' || booking.rows[0].status === 'SERVICE_COMPLETED') {
        await transitionBooking(client, booking.rows[0], booking.rows[0].status === 'SERVICE_COMPLETED' ? 'CUSTOMER_FEEDBACK_PENDING' : 'COMPLETED', req.user.sub, 'Customer review submitted');
        if (booking.rows[0].status === 'CUSTOMER_FEEDBACK_PENDING') {
          await transitionBooking(client, booking.rows[0], 'COMPLETED', req.user.sub, 'Closed after review');
        }
      }
      await client.query('COMMIT');
      res.status(201).json({ success: true, data: r.rows[0] });
    } catch (e) {
      await client.query('ROLLBACK');
      if (e.code === '23505') return res.status(422).json({ success: false, message: 'Review already submitted' });
      throw e;
    } finally {
      client.release();
    }
  }));

  router.get('/rewards', authRequired(), wrap(async (req, res) => {
    const balance = await currentPoints(req.user.sub);
    const tx = await pool.query('SELECT * FROM points_ledger WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50', [req.user.sub]);
    const catalog = await pool.query('SELECT * FROM rewards WHERE is_active = true');
    res.json({
      success: true,
      data: { total_balance: balance, transactions: tx.rows, rewards: catalog.rows },
    });
  }));

  router.post('/rewards/redeem', authRequired(), wrap(async (req, res) => {
    const { reward_id } = req.body || {};
    const reward = await pool.query('SELECT * FROM rewards WHERE id = $1 AND is_active = true', [reward_id]);
    if (!reward.rows[0]) return res.status(404).json({ success: false, message: 'Reward not found' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const balance = await currentPoints(req.user.sub);
      if (balance < reward.rows[0].points_cost) {
        await client.query('ROLLBACK');
        return res.status(422).json({ success: false, message: 'Not enough STARQ points' });
      }
      await addPoints(client, req.user.sub, null, -reward.rows[0].points_cost, `Redeemed ${reward.rows[0].name}`);
      const red = await client.query(
        'INSERT INTO reward_redemptions (user_id, reward_id, points_spent) VALUES ($1,$2,$3) RETURNING *',
        [req.user.sub, reward_id, reward.rows[0].points_cost],
      );
      await client.query('COMMIT');
      res.status(201).json({ success: true, data: red.rows[0] });
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }));

  router.get('/notifications', authRequired(), wrap(async (req, res) => {
    const r = await pool.query('SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50', [req.user.sub]);
    res.json({ success: true, data: r.rows });
  }));

  // ---------- Admin ----------
  router.get('/admin/bookings', authRequired('admin', 'operator'), wrap(async (_req, res) => {
    const r = await pool.query('SELECT * FROM bookings ORDER BY created_at DESC LIMIT 200');
    const data = [];
    for (const row of r.rows) data.push(await hydrateBooking(row));
    res.json({ success: true, data });
  }));

  router.get('/admin/partners', authRequired('admin', 'operator'), wrap(async (_req, res) => {
    const r = await pool.query(
      `SELECT p.*, u.full_name, u.email, u.phone FROM partners p JOIN users u ON u.id = p.user_id ORDER BY u.full_name`,
    );
    res.json({ success: true, data: r.rows });
  }));

  router.post('/admin/bookings/:id/assign', authRequired('admin', 'operator'), wrap(async (req, res) => {
    const { partner_id } = req.body || {};
    const bookingRes = await pool.query('SELECT * FROM bookings WHERE id = $1', [req.params.id]);
    if (!bookingRes.rows[0]) return res.status(404).json({ success: false, message: 'Booking not found' });
    const partner = await pool.query('SELECT * FROM partners WHERE id = $1', [partner_id]);
    if (!partner.rows[0]) return res.status(404).json({ success: false, message: 'Partner not found' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const booking = bookingRes.rows[0];
      await client.query('UPDATE bookings SET partner_id = $1 WHERE id = $2', [partner_id, booking.id]);
      if (booking.status === 'CONFIRMED') await transitionBooking(client, booking, 'ASSIGNMENT_PENDING', req.user.sub, 'Admin assign');
      if (booking.status === 'ASSIGNMENT_PENDING') await transitionBooking(client, booking, 'PARTNER_ASSIGNED', req.user.sub, 'Admin assigned partner');
      else if (booking.status === 'PARTNER_ASSIGNED') {
        await client.query('UPDATE bookings SET updated_at = NOW() WHERE id = $1', [booking.id]);
      } else {
        assertTransition(booking.status, 'PARTNER_ASSIGNED');
      }
      await client.query("UPDATE partners SET is_available = false, status = 'on_job' WHERE id = $1", [partner_id]);
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
    const fresh = await pool.query('SELECT * FROM bookings WHERE id = $1', [req.params.id]);
    res.json({ success: true, data: await hydrateBooking(fresh.rows[0]) });
  }));

  async function confirmCapturedPayment(orderId, paymentId) {
    const pay = await pool.query('SELECT * FROM payments WHERE razorpay_order_id = $1', [orderId]);
    if (!pay.rows[0]) return null;
    if (pay.rows[0].status === 'success') {
      const booking = await pool.query('SELECT * FROM bookings WHERE id = $1', [pay.rows[0].booking_id]);
      return hydrateBooking(booking.rows[0]);
    }
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `UPDATE payments SET razorpay_payment_id = COALESCE(razorpay_payment_id, $1), status = 'success', updated_at = NOW()
         WHERE id = $2`,
        [paymentId, pay.rows[0].id],
      );
      const bookingRes = await client.query('SELECT * FROM bookings WHERE id = $1', [pay.rows[0].booking_id]);
      await confirmPaidBooking(client, bookingRes.rows[0], null, 'Razorpay webhook payment.captured');
      await client.query('COMMIT');
      const fresh = await pool.query('SELECT * FROM bookings WHERE id = $1', [pay.rows[0].booking_id]);
      return hydrateBooking(fresh.rows[0]);
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  return { router, verifyAndConfirm, confirmCapturedPayment, hydrateBooking };
}

module.exports = { createRouter };
