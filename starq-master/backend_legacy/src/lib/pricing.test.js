const test = require('node:test');
const assert = require('node:assert/strict');
const { computeQuote, rupeesToPaise } = require('./pricing');

test('authoritative quote includes GST on subtotal plus fee', () => {
  const q = computeQuote({ basePrice: 249, addOnPrices: [49] });
  assert.equal(q.base_service_amount, 249);
  assert.equal(q.add_ons_amount, 49);
  assert.equal(q.convenience_fee, 30);
  assert.equal(q.tax_amount, 59.04);
  assert.equal(q.final_total_amount, 387.04);
});

test('paise conversion is integer', () => {
  assert.equal(rupeesToPaise(387.04), 38704);
});
