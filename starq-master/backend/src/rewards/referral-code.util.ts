import * as crypto from 'crypto';

/**
 * Characters used for referral code suffix.
 * Excludes ambiguous characters (0, O, 1, I, L) to reduce user entry errors.
 */
const REFERRAL_CHARSET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

/**
 * Normalizes a referral code by trimming whitespace and converting to uppercase.
 */
export function normalizeReferralCode(code?: string | null): string {
  if (!code) return '';
  return code.trim().toUpperCase();
}

/**
 * Validates whether a referral code matches the expected STARQ format.
 * Format: "STARQ" followed by 3 to 6 alphanumeric characters.
 */
export function isValidReferralCodeFormat(code?: string | null): boolean {
  if (!code) return false;
  const normalized = normalizeReferralCode(code);
  return /^STARQ[A-Z0-9]{3,8}$/.test(normalized);
}

/**
 * Generates a cryptographically secure random referral code.
 * Example outputs: "STARQ4K9X2M", "STARQ7MN2WP"
 * Default suffix length: 6 characters (providing 387M+ unique combinations).
 */
export function generateRandomReferralCode(suffixLength = 6): string {
  const bytes = crypto.randomBytes(suffixLength);
  let suffix = '';
  for (let i = 0; i < suffixLength; i++) {
    const index = bytes[i] % REFERRAL_CHARSET.length;
    suffix += REFERRAL_CHARSET[index];
  }
  return `STARQ${suffix}`;
}

/**
 * Calculates booking reward points per STARQ Points rules:
 * 5 points for every ₹100 spent (rounded down).
 */
export function calculateBookingPoints(amountPaidInRupees: number): number {
  if (!amountPaidInRupees || amountPaidInRupees <= 0) return 0;
  return Math.floor((amountPaidInRupees * 5) / 100);
}

/**
 * Calculates max points usable on a booking per STARQ Points rules:
 * Max discount is 30% of booking value (1 point = ₹1 discount).
 * The discount is the smaller of customer balance and 30% cap.
 */
export function calculateMaxRedeemablePoints(balance: number, bookingTotal: number): number {
  if (balance <= 0 || bookingTotal <= 0) return 0;
  const cap = Math.floor((bookingTotal * 30) / 100);
  return Math.min(balance, cap);
}

/**
 * Expiration duration for all STARQ Points: 90 days.
 */
export const POINTS_EXPIRY_DAYS = 90;

/**
 * Referral reward point amount per rule: 100 points to both referrer and friend.
 */
export const REFERRAL_REWARD_POINTS = 100;

export function calculatePointsExpiryDate(fromDate: Date = new Date()): Date {
  const expiry = new Date(fromDate);
  expiry.setDate(expiry.getDate() + POINTS_EXPIRY_DAYS);
  return expiry;
}

export interface LedgerEntryLike {
  points: number;
  createdAt: Date | string;
  expiresAt?: Date | string | null;
}

export interface PointsCalculationResult {
  activeBalance: number;
  expiredPointsTotal: number;
  expiringPoints: number;
  expiringOn: Date | null;
}

/**
 * Calculates user's spendable balance, expired points, and upcoming expiring points
 * using FIFO (First-In, First-Out) consumption per STARQ Points specification.
 * - Oldest points are consumed first by past redemptions so they are spent before they expire.
 * - Expired points cannot be redeemed.
 */
export function calculateUserPointsSummary(
  entries: LedgerEntryLike[],
  asOfDate: Date = new Date()
): PointsCalculationResult {
  // Sort chronologically (oldest first)
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
  );

  // Total debits (spent/redeemed points, represented as negative numbers)
  let totalDebitsRemaining = sorted
    .filter((e) => e.points < 0)
    .reduce((sum, e) => sum + Math.abs(e.points), 0);

  let activeBalance = 0;
  let expiredPointsTotal = 0;
  let expiringPoints = 0;
  let expiringOn: Date | null = null;

  // Process earned credit batches in FIFO order
  for (const entry of sorted) {
    if (entry.points <= 0) continue; // Skip debits, already aggregated

    let availableFromBatch = entry.points;

    // Consume from this batch using FIFO debits
    if (totalDebitsRemaining > 0) {
      const consumed = Math.min(availableFromBatch, totalDebitsRemaining);
      availableFromBatch -= consumed;
      totalDebitsRemaining -= consumed;
    }

    if (availableFromBatch <= 0) {
      continue; // This entire batch was already redeemed/spent
    }

    // Check expiration against asOfDate
    const isExpired =
      entry.expiresAt != null &&
      new Date(entry.expiresAt).getTime() <= asOfDate.getTime();

    if (isExpired) {
      expiredPointsTotal += availableFromBatch;
    } else {
      activeBalance += availableFromBatch;

      // Track the soonest expiring batch
      if (entry.expiresAt != null) {
        const batchExpiry = new Date(entry.expiresAt);
        if (expiringOn === null || batchExpiry.getTime() < expiringOn.getTime()) {
          expiringOn = batchExpiry;
          expiringPoints = availableFromBatch;
        } else if (batchExpiry.getTime() === expiringOn.getTime()) {
          expiringPoints += availableFromBatch;
        }
      }
    }
  }

  return {
    activeBalance,
    expiredPointsTotal,
    expiringPoints,
    expiringOn,
  };
}
