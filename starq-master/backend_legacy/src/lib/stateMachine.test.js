const test = require('node:test');
const assert = require('node:assert/strict');
const { assertTransition, isTrackingActive } = require('./stateMachine');

test('allows confirmed to assignment pending', () => {
  assert.doesNotThrow(() => assertTransition('CONFIRMED', 'ASSIGNMENT_PENDING'));
});

test('rejects completed to confirmed', () => {
  assert.throws(() => assertTransition('COMPLETED', 'CONFIRMED'));
});

test('tracking only during partner transit states', () => {
  assert.equal(isTrackingActive('PARTNER_ON_THE_WAY'), true);
  assert.equal(isTrackingActive('SERVICE_STARTED'), false);
});
