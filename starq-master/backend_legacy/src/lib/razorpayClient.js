const Razorpay = require('razorpay');

function razorpayConfigured() {
  return Boolean(process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET);
}

function getClient() {
  if (!razorpayConfigured()) {
    const err = new Error(
      'Razorpay credentials are not configured. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET on the backend.',
    );
    err.status = 503;
    err.code = 'RAZORPAY_NOT_CONFIGURED';
    throw err;
  }
  return new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID,
    key_secret: process.env.RAZORPAY_KEY_SECRET,
  });
}

module.exports = { razorpayConfigured, getClient };
