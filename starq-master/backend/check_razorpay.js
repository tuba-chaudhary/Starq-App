const dotenv = require('dotenv');
dotenv.config();

const Razorpay = require('razorpay');

async function checkRazorpay() {
  const key_id = process.env.RAZORPAY_KEY_ID;
  const key_secret = process.env.RAZORPAY_KEY_SECRET;

  const detected = (key_id && key_id !== 'dummy_key_id') && (key_secret && key_secret !== 'dummy_key_secret');
  console.log('Credentials Detected:', detected ? 'yes' : 'no');

  if (detected) {
    try {
      const razorpay = new Razorpay({ key_id, key_secret });
      
      // Attempt to create a test order
      const order = await razorpay.orders.create({
        amount: 100, // 1 INR in paise
        currency: 'INR',
        receipt: 'test_receipt_123',
      });
      
      console.log('Razorpay Initialization & Test Order:', order && order.id ? 'success' : 'failed');
    } catch (error) {
      console.log('Razorpay Initialization & Test Order: failed');
      console.error('Exact blocker:', error.message || error.description || error);
    }
  } else {
    console.log('Razorpay Initialization & Test Order: skipped (no credentials)');
  }
}

checkRazorpay();
