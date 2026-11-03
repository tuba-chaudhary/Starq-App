import {
  Injectable,
  NotFoundException,
  ConflictException,
  InternalServerErrorException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  generateRandomReferralCode,
  calculateUserPointsSummary,
  calculatePointsExpiryDate,
  REFERRAL_REWARD_POINTS,
} from './referral-code.util';

export interface PointsSummaryDto {
  balance: number;
  expiringPoints: number;
  expiringOn: string | null;
  expiredPointsTotal: number;
}

export interface PointsEntryDto {
  id: string;
  points: number;
  type: string;
  description: string | null;
  bookingId: string | null;
  expiresAt: string | null;
  createdAt: string;
}

export interface ReferralSummaryDto {
  referralCode: string;
  totalReferrals: number;
  successfulReferrals: number;
  pendingReferrals: number;
  pointsPerSuccessfulReferral: number;
  totalPointsEarned: number;
  referrals: Array<{
    id: string;
    refereeId: string;
    refereeName: string;
    refereePhoneMasked: string | null;
    status: string;
    rewardedAt: string | null;
    createdAt: string;
  }>;
}

export interface AwardReferralResult {
  awarded: boolean;
  reason?: string;
  referralId?: string;
  referrerPointsAwarded?: number;
  refereePointsAwarded?: number;
}

@Injectable()
export class RewardsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Retrieves points summary (active balance, expiring points, expired points)
   * derived directly from the user's PointsLedger records without a separate balance column.
   */
  async getPointsSummary(userId: string): Promise<PointsSummaryDto> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const entries = await this.prisma.pointsLedger.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });

    const summary = calculateUserPointsSummary(entries, new Date());

    return {
      balance: summary.activeBalance,
      expiringPoints: summary.expiringPoints,
      expiringOn: summary.expiringOn ? summary.expiringOn.toISOString() : null,
      expiredPointsTotal: summary.expiredPointsTotal,
    };
  }

  /**
   * Retrieves paginated or limited history of user's points ledger records.
   */
  async getPointsHistory(userId: string, limit = 50): Promise<{ history: PointsEntryDto[]; total: number }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const safeLimit = Math.min(Math.max(limit, 1), 100);

    const [entries, total] = await Promise.all([
      this.prisma.pointsLedger.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: safeLimit,
      }),
      this.prisma.pointsLedger.count({ where: { userId } }),
    ]);

    const history: PointsEntryDto[] = entries.map((entry) => ({
      id: entry.id,
      points: entry.points,
      type: entry.type || 'earned_referral',
      description: entry.description,
      bookingId: entry.bookingId,
      expiresAt: entry.expiresAt ? entry.expiresAt.toISOString() : null,
      createdAt: entry.createdAt.toISOString(),
    }));

    return { history, total };
  }

  /**
   * Returns user's permanent referral code, or generates and stores one with collision retry.
   */
  async getOrCreateReferralCode(userId: string): Promise<{ referralCode: string }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, referralCode: true },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (user.referralCode) {
      return { referralCode: user.referralCode };
    }

    const MAX_RETRIES = 5;
    for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
      const candidateCode = generateRandomReferralCode();
      try {
        const updated = await this.prisma.user.update({
          where: { id: userId },
          data: { referralCode: candidateCode },
          select: { referralCode: true },
        });
        return { referralCode: updated.referralCode! };
      } catch (err: any) {
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
          // Check if concurrent request already set this user's referral code
          const recheck = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { referralCode: true },
          });
          if (recheck?.referralCode) {
            return { referralCode: recheck.referralCode };
          }
          if (attempt === MAX_RETRIES) {
            throw new ConflictException(
              'Failed to generate unique referral code after multiple attempts. Please retry.',
            );
          }
          continue;
        }
        throw err;
      }
    }

    throw new InternalServerErrorException('Unexpected error generating referral code');
  }

  /**
   * Retrieves referral performance metrics and list of invited referees.
   */
  async getReferralSummary(userId: string): Promise<ReferralSummaryDto> {
    const { referralCode } = await this.getOrCreateReferralCode(userId);

    const referrals = await this.prisma.referral.findMany({
      where: { referrerId: userId },
      include: {
        referee: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            createdAt: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const totalReferrals = referrals.length;
    const successfulReferrals = referrals.filter((r) => r.status === 'REWARDED').length;
    const pendingReferrals = referrals.filter((r) => r.status === 'PENDING').length;
    const totalPointsEarned = successfulReferrals * REFERRAL_REWARD_POINTS;

    const mappedReferrals = referrals.map((r) => ({
      id: r.id,
      refereeId: r.refereeId,
      refereeName: r.referee?.fullName || 'STARQ Customer',
      refereePhoneMasked: r.referee?.phone ? this.maskPhone(r.referee.phone) : null,
      status: r.status,
      rewardedAt: r.rewardedAt ? r.rewardedAt.toISOString() : null,
      createdAt: r.createdAt.toISOString(),
    }));

    return {
      referralCode,
      totalReferrals,
      successfulReferrals,
      pendingReferrals,
      pointsPerSuccessfulReferral: REFERRAL_REWARD_POINTS,
      totalPointsEarned,
      referrals: mappedReferrals,
    };
  }

  /**
   * Evaluates eligibility and awards referral points to both referrer and referee
   * upon the referee's FIRST completed and verified paid booking.
   * - Enforces exactly-once rewards via atomic conditional update (updateMany with status: 'PENDING')
   * - Deterministic unique idempotency keys on PointsLedger entries
   * - Requires booking status COMPLETED and captured payment with amount > 0
   */
  async awardReferralRewardIfEligible(bookingId: string): Promise<AwardReferralResult> {
    if (!bookingId) {
      return { awarded: false, reason: 'Invalid booking ID' };
    }

    try {
      return await this.prisma.$transaction(async (tx) => {
        // 1. Fetch booking with payments
        const booking = await tx.booking.findUnique({
          where: { id: bookingId },
          include: { payments: true },
        });

        if (!booking) {
          return { awarded: false, reason: 'Booking not found' };
        }

        // 2. Booking must be COMPLETED
        if (booking.status !== 'COMPLETED') {
          return {
            awarded: false,
            reason: `Booking status is ${booking.status}, not COMPLETED`,
          };
        }

        // 3. Payment must be captured and amount > 0
        const capturedPayments = (booking.payments || []).filter(
          (p) => p.status === 'captured' && p.amount > 0,
        );

        if (capturedPayments.length === 0) {
          return {
            awarded: false,
            reason: 'Booking does not have a verified captured payment with amount > 0',
          };
        }

        // 4. Find referral for this customer (referee)
        const referral = await tx.referral.findUnique({
          where: { refereeId: booking.userId },
        });

        if (!referral) {
          return {
            awarded: false,
            reason: 'Customer was not referred by anyone (no referral record found)',
          };
        }

        if (referral.status === 'REWARDED') {
          return {
            awarded: false,
            reason: 'Referral has already been rewarded',
          };
        }

        if (referral.status !== 'PENDING') {
          return {
            awarded: false,
            reason: `Referral status is ${referral.status}, not PENDING`,
          };
        }

        // 5. Confirm this is the referee's FIRST qualifying completed-and-paid booking
        const qualifyingBookings = await tx.booking.findMany({
          where: {
            userId: booking.userId,
            status: 'COMPLETED',
            payments: {
              some: {
                status: 'captured',
                amount: { gt: 0 },
              },
            },
          },
          orderBy: [
            { scheduledAt: 'asc' },
            { createdAt: 'asc' },
          ],
          select: { id: true, createdAt: true },
        });

        if (qualifyingBookings.length > 0 && qualifyingBookings[0].id !== booking.id) {
          return {
            awarded: false,
            reason: 'Booking is not the customer first qualifying completed-and-paid booking',
          };
        }

        // 6. Concurrency Control: Atomic conditional update
        const updateResult = await tx.referral.updateMany({
          where: {
            id: referral.id,
            status: 'PENDING',
          },
          data: {
            status: 'REWARDED',
            qualifyingBookingId: booking.id,
            rewardedAt: new Date(),
          },
        });

        if (updateResult.count === 0) {
          return {
            awarded: false,
            reason: 'Referral was already rewarded by a concurrent process',
          };
        }

        // 7. Create exactly two PointsLedger entries (100 pts each) with distinct, stable idempotency keys
        const expiresAt = calculatePointsExpiryDate(new Date());
        const referrerIdempotencyKey = `ref_reward_referrer_${referral.id}_${booking.id}`;
        const refereeIdempotencyKey = `ref_reward_referee_${referral.id}_${booking.id}`;

        await tx.pointsLedger.create({
          data: {
            userId: referral.referrerId,
            points: REFERRAL_REWARD_POINTS,
            type: 'earned_referral',
            description: 'Referral reward: friend completed first booking',
            bookingId: booking.id,
            expiresAt,
            idempotencyKey: referrerIdempotencyKey,
          },
        });

        await tx.pointsLedger.create({
          data: {
            userId: referral.refereeId,
            points: REFERRAL_REWARD_POINTS,
            type: 'earned_referral',
            description: 'Welcome referral reward: first booking completed',
            bookingId: booking.id,
            expiresAt,
            idempotencyKey: refereeIdempotencyKey,
          },
        });

        return {
          awarded: true,
          referralId: referral.id,
          referrerPointsAwarded: REFERRAL_REWARD_POINTS,
          refereePointsAwarded: REFERRAL_REWARD_POINTS,
        };
      });
    } catch (err: any) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        return {
          awarded: false,
          reason: 'Duplicate referral reward or idempotency conflict detected',
        };
      }
      throw err;
    }
  }

  private maskPhone(phone: string): string {
    const trimmed = phone.trim();
    if (trimmed.length <= 4) return '****';
    const firstTwo = trimmed.slice(0, 2);
    const lastFour = trimmed.slice(-4);
    return `${firstTwo}****${lastFour}`;
  }
}
