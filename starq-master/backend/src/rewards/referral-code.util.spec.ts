import {
  generateRandomReferralCode,
  normalizeReferralCode,
  isValidReferralCodeFormat,
  calculateBookingPoints,
  calculateMaxRedeemablePoints,
  calculatePointsExpiryDate,
  calculateUserPointsSummary,
  POINTS_EXPIRY_DAYS,
  REFERRAL_REWARD_POINTS,
} from './referral-code.util';

describe('ReferralCodeUtil', () => {
  describe('generateRandomReferralCode', () => {
    it('should generate a code with prefix STARQ and expected length', () => {
      const code = generateRandomReferralCode();
      expect(code.startsWith('STARQ')).toBe(true);
      expect(code.length).toBe(11); // STARQ (5) + 6 chars = 11
    });

    it('should generate distinct codes without collisions across multiple generations', () => {
      const generated = new Set<string>();
      const count = 500;
      for (let i = 0; i < count; i++) {
        const code = generateRandomReferralCode();
        expect(generated.has(code)).toBe(false);
        generated.add(code);
      }
      expect(generated.size).toBe(count);
    });

    it('should only use non-ambiguous uppercase characters', () => {
      for (let i = 0; i < 50; i++) {
        const code = generateRandomReferralCode();
        // Suffix should not contain 0, O, 1, I, L
        const suffix = code.substring(5);
        expect(suffix).not.toMatch(/[0O1IL]/);
      }
    });
  });

  describe('normalizeReferralCode', () => {
    it('should trim and uppercase the referral code', () => {
      expect(normalizeReferralCode('  starq123  ')).toBe('STARQ123');
      expect(normalizeReferralCode('starq4k9x')).toBe('STARQ4K9X');
    });

    it('should handle empty or null values safely', () => {
      expect(normalizeReferralCode('')).toBe('');
      expect(normalizeReferralCode(null)).toBe('');
      expect(normalizeReferralCode(undefined)).toBe('');
    });
  });

  describe('isValidReferralCodeFormat', () => {
    it('should accept valid STARQ code formats', () => {
      expect(isValidReferralCodeFormat('STARQ123')).toBe(true);
      expect(isValidReferralCodeFormat('starq123')).toBe(true);
      expect(isValidReferralCodeFormat('STARQ4K9X')).toBe(true);
    });

    it('should reject invalid formats', () => {
      expect(isValidReferralCodeFormat('')).toBe(false);
      expect(isValidReferralCodeFormat('STARQ')).toBe(false);
      expect(isValidReferralCodeFormat('INVALID123')).toBe(false);
      expect(isValidReferralCodeFormat('STARQ!@#')).toBe(false);
    });
  });

  describe('STARQ Points Rules calculations (per specification PDF)', () => {
    it('should calculate 5 points per ₹100 spent (rounded down)', () => {
      expect(calculateBookingPoints(249)).toBe(12);
      expect(calculateBookingPoints(399)).toBe(19);
      expect(calculateBookingPoints(999)).toBe(49);
      expect(calculateBookingPoints(1299)).toBe(64);
      expect(calculateBookingPoints(279)).toBe(13);
      expect(calculateBookingPoints(99)).toBe(4);
      expect(calculateBookingPoints(50)).toBe(2);
      expect(calculateBookingPoints(0)).toBe(0);
    });

    it('should cap redemption at 30% of booking value or available balance', () => {
      // PDF example: booking 279 -> 30% cap is 83
      expect(calculateMaxRedeemablePoints(240, 279)).toBe(83);
      expect(calculateMaxRedeemablePoints(50, 279)).toBe(50);
      expect(calculateMaxRedeemablePoints(0, 279)).toBe(0);
    });

    it('should award 100 points for referral rewards', () => {
      expect(REFERRAL_REWARD_POINTS).toBe(100);
    });

    it('should set 90-day expiry date', () => {
      const baseDate = new Date('2026-01-01T00:00:00Z');
      const expiry = calculatePointsExpiryDate(baseDate);
      const diffDays = Math.round((expiry.getTime() - baseDate.getTime()) / (1000 * 60 * 60 * 24));
      expect(diffDays).toBe(POINTS_EXPIRY_DAYS);
      expect(POINTS_EXPIRY_DAYS).toBe(90);
    });
  });

  describe('calculateUserPointsSummary (FIFO consumption & expiration rules)', () => {
    it('should calculate active balance when no points have expired or been redeemed', () => {
      const entries = [
        { points: 100, createdAt: new Date('2026-01-01'), expiresAt: new Date('2026-04-01') },
        { points: 50, createdAt: new Date('2026-02-01'), expiresAt: new Date('2026-05-01') },
      ];
      const result = calculateUserPointsSummary(entries, new Date('2026-02-15'));
      expect(result.activeBalance).toBe(150);
      expect(result.expiredPointsTotal).toBe(0);
      expect(result.expiringPoints).toBe(100);
      expect(result.expiringOn).toEqual(new Date('2026-04-01'));
    });

    it('should consume oldest points first (FIFO) upon redemption', () => {
      const entries = [
        { points: 100, createdAt: new Date('2026-01-01'), expiresAt: new Date('2026-04-01') },
        { points: 50, createdAt: new Date('2026-02-01'), expiresAt: new Date('2026-05-01') },
        { points: -40, createdAt: new Date('2026-02-15'), expiresAt: null }, // Redeemed 40
      ];
      // On 2026-02-20: 40 points deducted from oldest (Jan 1) batch -> 60 left in Jan 1 batch
      const result = calculateUserPointsSummary(entries, new Date('2026-02-20'));
      expect(result.activeBalance).toBe(110);
      expect(result.expiredPointsTotal).toBe(0);
      expect(result.expiringPoints).toBe(60);
      expect(result.expiringOn).toEqual(new Date('2026-04-01'));
    });

    it('should not allow expired points to be redeemed and correctly deduct them from balance', () => {
      const entries = [
        { points: 100, createdAt: new Date('2026-01-01'), expiresAt: new Date('2026-04-01') },
        { points: 50, createdAt: new Date('2026-02-01'), expiresAt: new Date('2026-05-01') },
        { points: -40, createdAt: new Date('2026-02-15'), expiresAt: null },
      ];
      // On 2026-04-05: The remaining 60 points from Jan 1 batch have now expired!
      const result = calculateUserPointsSummary(entries, new Date('2026-04-05'));
      expect(result.activeBalance).toBe(50); // Only Feb 1 batch remains spendable
      expect(result.expiredPointsTotal).toBe(60);
      expect(result.expiringPoints).toBe(50);
      expect(result.expiringOn).toEqual(new Date('2026-05-01'));
    });

    it('should not count fully spent batches as expired after their expiry date', () => {
      const entries = [
        { points: 100, createdAt: new Date('2026-01-01'), expiresAt: new Date('2026-04-01') },
        { points: -100, createdAt: new Date('2026-01-20'), expiresAt: null }, // Entire batch spent
      ];
      // On 2026-05-01: Since all 100 pts were spent before expiry, 0 points expire
      const result = calculateUserPointsSummary(entries, new Date('2026-05-01'));
      expect(result.activeBalance).toBe(0);
      expect(result.expiredPointsTotal).toBe(0);
      expect(result.expiringPoints).toBe(0);
      expect(result.expiringOn).toBeNull();
    });
  });
});
