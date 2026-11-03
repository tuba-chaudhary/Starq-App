const CONVENIENCE_FEE = 30;
const GST_RATE = 0.18;
const POINTS_RATE = 0.1;

function roundMoney(n) {
  return Math.round(Number(n) * 100) / 100;
}

function computeQuote({ basePrice, addOnPrices, convenienceFee = CONVENIENCE_FEE }) {
  const baseServiceAmount = roundMoney(basePrice);
  const addOnsAmount = roundMoney((addOnPrices || []).reduce((s, p) => s + Number(p), 0));
  const fee = roundMoney(convenienceFee);
  const taxable = roundMoney(baseServiceAmount + addOnsAmount + fee);
  const taxAmount = roundMoney(taxable * GST_RATE);
  const discountAmount = 0;
  const finalTotalAmount = roundMoney(taxable + taxAmount - discountAmount);
  const pointsAwarded = Math.round(finalTotalAmount * POINTS_RATE);
  return {
    base_service_amount: baseServiceAmount,
    add_ons_amount: addOnsAmount,
    convenience_fee: fee,
    tax_amount: taxAmount,
    discount_amount: discountAmount,
    final_total_amount: finalTotalAmount,
    points_awarded: pointsAwarded,
  };
}

function rupeesToPaise(amount) {
  return Math.round(Number(amount) * 100);
}

module.exports = { CONVENIENCE_FEE, GST_RATE, POINTS_RATE, computeQuote, rupeesToPaise, roundMoney };
