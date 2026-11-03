import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException, ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { RewardsService } from './rewards.service';
import { RewardsController } from './rewards.controller';
import { PrismaService } from '../prisma/prisma.service';

describe('RewardsModule', () => {
  let service: RewardsService;
  let controller: RewardsController;
  let prisma: PrismaService;

  const mockPrisma = {
    user: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    pointsLedger: {
      findMany: jest.fn(),
      count: jest.fn(),
      create: jest.fn(),
    },
    referral: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      updateMany: jest.fn(),
    },
    booking: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
    },
    $transaction: jest.fn(async (cb) => {
      if (typeof cb === 'function') {
        return cb(mockPrisma);
      }
      return Promise.all(cb);
    }),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [RewardsController],
      providers: [
        RewardsService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
      ],
    }).compile();

    service = module.get<RewardsService>(RewardsService);
    controller = module.get<RewardsController>(RewardsController);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should have service and controller defined', () => {
    expect(service).toBeDefined();
    expect(controller).toBeDefined();
  });

  describe('RewardsService.getPointsSummary', () => {
    it('should derive active points balance from ledger records without a separate balance column', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user-1' });
      mockPrisma.pointsLedger.findMany.mockResolvedValue([
        {
          id: 'entry-1',
          userId: 'user-1',
          points: 100,
          type: 'earned_referral',
          createdAt: new Date('2026-10-01T00:00:00Z'),
          expiresAt: new Date('2026-12-30T00:00:00Z'),
        },
        {
          id: 'entry-2',
          userId: 'user-1',
          points: -30,
          type: 'redeemed',
          createdAt: new Date('2026-10-05T00:00:00Z'),
          expiresAt: null,
        },
      ]);

      const result = await service.getPointsSummary('user-1');

      expect(mockPrisma.user.findUnique).toHaveBeenCalledWith({
        where: { id: 'user-1' },
        select: { id: true },
      });
      expect(result.balance).toBe(70);
      expect(result.expiredPointsTotal).toBe(0);
      expect(result.expiringPoints).toBe(70);
      expect(result.expiringOn).toBe(new Date('2026-12-30T00:00:00Z').toISOString());
    });

    it('should return 0 balance when user has no ledger entries', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user-1' });
      mockPrisma.pointsLedger.findMany.mockResolvedValue([]);

      const result = await service.getPointsSummary('user-1');
      expect(result.balance).toBe(0);
      expect(result.expiringPoints).toBe(0);
      expect(result.expiringOn).toBeNull();
      expect(result.expiredPointsTotal).toBe(0);
    });

    it('should throw NotFoundException if user does not exist', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);

      await expect(service.getPointsSummary('non-existent')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('RewardsService.getPointsHistory', () => {
    it('should return formatted ledger entries in descending order', async () => {
      const now = new Date();
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user-1' });
      mockPrisma.pointsLedger.findMany.mockResolvedValue([
        {
          id: 'p-1',
          userId: 'user-1',
          points: 100,
          type: 'earned_referral',
          description: 'Referral reward',
          bookingId: null,
          expiresAt: null,
          createdAt: now,
        },
      ]);
      mockPrisma.pointsLedger.count.mockResolvedValue(1);

      const result = await service.getPointsHistory('user-1', 20);

      expect(result.total).toBe(1);
      expect(result.history).toHaveLength(1);
      expect(result.history[0]).toEqual({
        id: 'p-1',
        points: 100,
        type: 'earned_referral',
        description: 'Referral reward',
        bookingId: null,
        expiresAt: null,
        createdAt: now.toISOString(),
      });
    });

    it('should throw NotFoundException when user does not exist', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);

      await expect(service.getPointsHistory('non-existent')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('RewardsService.getOrCreateReferralCode', () => {
    it('should return existing referral code without updating if user already has one', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user-1',
        referralCode: 'STARQEXISTING',
      });

      const result = await service.getOrCreateReferralCode('user-1');

      expect(result.referralCode).toBe('STARQEXISTING');
      expect(mockPrisma.user.update).not.toHaveBeenCalled();
    });

    it('should generate, save, and return a referral code if user has none', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user-1',
        referralCode: null,
      });
      mockPrisma.user.update.mockResolvedValue({
        referralCode: 'STARQNEW123',
      });

      const result = await service.getOrCreateReferralCode('user-1');

      expect(result.referralCode).toBe('STARQNEW123');
      expect(mockPrisma.user.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 'user-1' },
          data: expect.objectContaining({
            referralCode: expect.stringMatching(/^STARQ[A-Z0-9]{3,8}$/),
          }),
        }),
      );
    });

    it('should retry on Prisma P2002 collision and succeed on subsequent attempt', async () => {
      mockPrisma.user.findUnique
        .mockResolvedValueOnce({ id: 'user-1', referralCode: null })
        .mockResolvedValueOnce({ id: 'user-1', referralCode: null });

      const p2002Error = new Prisma.PrismaClientKnownRequestError(
        'Unique constraint violation',
        { code: 'P2002', clientVersion: '5.22.0' },
      );

      mockPrisma.user.update
        .mockRejectedValueOnce(p2002Error)
        .mockResolvedValueOnce({ referralCode: 'STARQSUCCESS' });

      const result = await service.getOrCreateReferralCode('user-1');

      expect(result.referralCode).toBe('STARQSUCCESS');
      expect(mockPrisma.user.update).toHaveBeenCalledTimes(2);
    });

    it('should return concurrent code if set by another request during collision', async () => {
      mockPrisma.user.findUnique
        .mockResolvedValueOnce({ id: 'user-1', referralCode: null })
        .mockResolvedValueOnce({ id: 'user-1', referralCode: 'STARQCONCURRENT' });

      const p2002Error = new Prisma.PrismaClientKnownRequestError(
        'Unique constraint violation',
        { code: 'P2002', clientVersion: '5.22.0' },
      );

      mockPrisma.user.update.mockRejectedValueOnce(p2002Error);

      const result = await service.getOrCreateReferralCode('user-1');

      expect(result.referralCode).toBe('STARQCONCURRENT');
      expect(mockPrisma.user.update).toHaveBeenCalledTimes(1);
    });

    it('should throw ConflictException if all 5 collision retries fail', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'user-1', referralCode: null });

      const p2002Error = new Prisma.PrismaClientKnownRequestError(
        'Unique constraint violation',
        { code: 'P2002', clientVersion: '5.22.0' },
      );

      mockPrisma.user.update.mockRejectedValue(p2002Error);

      await expect(service.getOrCreateReferralCode('user-1')).rejects.toThrow(
        ConflictException,
      );
      expect(mockPrisma.user.update).toHaveBeenCalledTimes(5);
    });

    it('should throw NotFoundException if user is not found', async () => {
      mockPrisma.user.findUnique.mockResolvedValue(null);

      await expect(service.getOrCreateReferralCode('missing')).rejects.toThrow(
        NotFoundException,
      );
    });
  });

  describe('RewardsService.getReferralSummary', () => {
    it('should calculate referral metrics and mask referee phone numbers', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user-1',
        referralCode: 'STARQ12345',
      });

      const now = new Date();
      mockPrisma.referral.findMany.mockResolvedValue([
        {
          id: 'ref-1',
          referrerId: 'user-1',
          refereeId: 'friend-1',
          referralCode: 'STARQ12345',
          status: 'REWARDED',
          rewardedAt: now,
          createdAt: now,
          referee: {
            id: 'friend-1',
            fullName: 'Jane Doe',
            phone: '9876543210',
            createdAt: now,
          },
        },
        {
          id: 'ref-2',
          referrerId: 'user-1',
          refereeId: 'friend-2',
          referralCode: 'STARQ12345',
          status: 'PENDING',
          rewardedAt: null,
          createdAt: now,
          referee: {
            id: 'friend-2',
            fullName: 'Bob Smith',
            phone: '9123456789',
            createdAt: now,
          },
        },
      ]);

      const summary = await service.getReferralSummary('user-1');

      expect(summary.referralCode).toBe('STARQ12345');
      expect(summary.totalReferrals).toBe(2);
      expect(summary.successfulReferrals).toBe(1);
      expect(summary.pendingReferrals).toBe(1);
      expect(summary.totalPointsEarned).toBe(100);
      expect(summary.pointsPerSuccessfulReferral).toBe(100);
      expect(summary.referrals).toHaveLength(2);
      expect(summary.referrals[0].refereePhoneMasked).toBe('98****3210');
      expect(summary.referrals[0].refereeName).toBe('Jane Doe');
      expect(summary.referrals[1].refereePhoneMasked).toBe('91****6789');
    });
  });

  describe('RewardsService.awardReferralRewardIfEligible', () => {
    const validBooking = {
      id: 'b-100',
      userId: 'referee-1',
      status: 'COMPLETED',
      payments: [{ id: 'pay-1', status: 'captured', amount: 499 }],
      scheduledAt: new Date('2026-10-23T10:00:00Z'),
      createdAt: new Date('2026-10-23T09:00:00Z'),
    };

    const pendingReferral = {
      id: 'ref-row-1',
      referrerId: 'referrer-1',
      refereeId: 'referee-1',
      status: 'PENDING',
      qualifyingBookingId: null,
      rewardedAt: null,
    };

    it('1. should return awarded: false if booking is COMPLETED but payment is NOT captured (booking completed before payment)', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'b-100',
        userId: 'referee-1',
        status: 'COMPLETED',
        payments: [{ id: 'pay-1', status: 'created', amount: 499 }], // not captured
      });

      const res = await service.awardReferralRewardIfEligible('b-100');

      expect(res.awarded).toBe(false);
      expect(res.reason).toMatch(/captured payment/i);
      expect(mockPrisma.referral.updateMany).not.toHaveBeenCalled();
      expect(mockPrisma.pointsLedger.create).not.toHaveBeenCalled();
    });

    it('2. should return awarded: false if payment is captured but booking is NOT COMPLETED (payment captured before booking completed)', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        id: 'b-100',
        userId: 'referee-1',
        status: 'CONFIRMED', // payment confirmed, service not completed yet
        payments: [{ id: 'pay-1', status: 'captured', amount: 499 }],
      });

      const res = await service.awardReferralRewardIfEligible('b-100');

      expect(res.awarded).toBe(false);
      expect(res.reason).toMatch(/status is CONFIRMED, not COMPLETED/i);
      expect(mockPrisma.referral.updateMany).not.toHaveBeenCalled();
      expect(mockPrisma.pointsLedger.create).not.toHaveBeenCalled();
    });

    it('3. should award exactly two 100-point ledger entries when both conditions are satisfied for the first qualifying booking', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(validBooking);
      mockPrisma.referral.findUnique.mockResolvedValue(pendingReferral);
      mockPrisma.booking.findMany.mockResolvedValue([{ id: 'b-100' }]);
      mockPrisma.referral.updateMany.mockResolvedValue({ count: 1 });
      mockPrisma.pointsLedger.create.mockResolvedValue({ id: 'pts-1' });

      const res = await service.awardReferralRewardIfEligible('b-100');

      expect(res.awarded).toBe(true);
      expect(res.referralId).toBe('ref-row-1');
      expect(res.referrerPointsAwarded).toBe(100);
      expect(res.refereePointsAwarded).toBe(100);

      // Verify atomic update on Referral
      expect(mockPrisma.referral.updateMany).toHaveBeenCalledWith({
        where: { id: 'ref-row-1', status: 'PENDING' },
        data: expect.objectContaining({
          status: 'REWARDED',
          qualifyingBookingId: 'b-100',
        }),
      });

      // Verify exactly two PointsLedger entries created with distinct, stable idempotency keys
      expect(mockPrisma.pointsLedger.create).toHaveBeenCalledTimes(2);

      // Referrer entry
      expect(mockPrisma.pointsLedger.create).toHaveBeenNthCalledWith(
        1,
        expect.objectContaining({
          data: expect.objectContaining({
            userId: 'referrer-1',
            points: 100,
            type: 'earned_referral',
            bookingId: 'b-100',
            idempotencyKey: 'ref_reward_referrer_ref-row-1_b-100',
          }),
        }),
      );

      // Referee entry
      expect(mockPrisma.pointsLedger.create).toHaveBeenNthCalledWith(
        2,
        expect.objectContaining({
          data: expect.objectContaining({
            userId: 'referee-1',
            points: 100,
            type: 'earned_referral',
            bookingId: 'b-100',
            idempotencyKey: 'ref_reward_referee_ref-row-1_b-100',
          }),
        }),
      );
    });

    it('4. should be idempotent on repeated booking completion or repeated payment webhook', async () => {
      // First invocation rewards referral.
      // Second invocation sees referral already REWARDED.
      mockPrisma.booking.findUnique.mockResolvedValue(validBooking);
      mockPrisma.referral.findUnique.mockResolvedValue({
        ...pendingReferral,
        status: 'REWARDED',
        qualifyingBookingId: 'b-100',
      });

      const res = await service.awardReferralRewardIfEligible('b-100');

      expect(res.awarded).toBe(false);
      expect(res.reason).toMatch(/already been rewarded/i);
      expect(mockPrisma.referral.updateMany).not.toHaveBeenCalled();
      expect(mockPrisma.pointsLedger.create).not.toHaveBeenCalled();
    });

    it('5. should handle concurrent race condition safely and award nothing if updateMany returns count 0', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(validBooking);
      mockPrisma.referral.findUnique.mockResolvedValue(pendingReferral);
      mockPrisma.booking.findMany.mockResolvedValue([{ id: 'b-100' }]);
      // Concurrent thread already updated status to REWARDED, so updateMany matches 0 rows
      mockPrisma.referral.updateMany.mockResolvedValue({ count: 0 });

      const res = await service.awardReferralRewardIfEligible('b-100');

      expect(res.awarded).toBe(false);
      expect(res.reason).toMatch(/already rewarded by a concurrent process/i);
      expect(mockPrisma.pointsLedger.create).not.toHaveBeenCalled();
    });

    it('6. should return awarded: false for zero/failed/unverified payment', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        ...validBooking,
        payments: [{ id: 'pay-fail', status: 'failed', amount: 499 }],
      });

      const res1 = await service.awardReferralRewardIfEligible('b-100');
      expect(res1.awarded).toBe(false);

      // Payment with zero amount
      mockPrisma.booking.findUnique.mockResolvedValue({
        ...validBooking,
        payments: [{ id: 'pay-zero', status: 'captured', amount: 0 }],
      });

      const res2 = await service.awardReferralRewardIfEligible('b-100');
      expect(res2.awarded).toBe(false);
      expect(mockPrisma.pointsLedger.create).not.toHaveBeenCalled();
    });

    it('7. should return awarded: false for booking in CANCELLED status', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue({
        ...validBooking,
        status: 'CANCELLED',
      });

      const res = await service.awardReferralRewardIfEligible('b-100');

      expect(res.awarded).toBe(false);
      expect(res.reason).toMatch(/status is CANCELLED/i);
      expect(mockPrisma.pointsLedger.create).not.toHaveBeenCalled();
    });

    it('8. should return awarded: false if customer was not referred (no referral record)', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(validBooking);
      mockPrisma.referral.findUnique.mockResolvedValue(null);

      const res = await service.awardReferralRewardIfEligible('b-100');

      expect(res.awarded).toBe(false);
      expect(res.reason).toMatch(/no referral record/i);
      expect(mockPrisma.referral.updateMany).not.toHaveBeenCalled();
      expect(mockPrisma.pointsLedger.create).not.toHaveBeenCalled();
    });

    it('9. should return awarded: false if referral status is already REWARDED', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(validBooking);
      mockPrisma.referral.findUnique.mockResolvedValue({
        ...pendingReferral,
        status: 'REWARDED',
      });

      const res = await service.awardReferralRewardIfEligible('b-100');

      expect(res.awarded).toBe(false);
      expect(res.reason).toMatch(/already been rewarded/i);
      expect(mockPrisma.pointsLedger.create).not.toHaveBeenCalled();
    });

    it('10. should return awarded: false if this is not the customer first qualifying completed-and-paid booking', async () => {
      mockPrisma.booking.findUnique.mockResolvedValue(validBooking);
      mockPrisma.referral.findUnique.mockResolvedValue(pendingReferral);

      // Customer already had an earlier completed and paid booking 'b-earlier'
      mockPrisma.booking.findMany.mockResolvedValue([
        { id: 'b-earlier', createdAt: new Date('2026-10-01T00:00:00Z') },
        { id: 'b-100', createdAt: new Date('2026-10-23T00:00:00Z') },
      ]);

      const res = await service.awardReferralRewardIfEligible('b-100');

      expect(res.awarded).toBe(false);
      expect(res.reason).toMatch(/not the customer first qualifying completed-and-paid booking/i);
      expect(mockPrisma.referral.updateMany).not.toHaveBeenCalled();
      expect(mockPrisma.pointsLedger.create).not.toHaveBeenCalled();
    });
  });

  describe('RewardsController endpoints', () => {
    const mockReq = { user: { id: 'authed-user-123', email: 'test@starq.com' } };

    it('GET /summary should extract req.user.id and call getPointsSummary', async () => {
      const spy = jest.spyOn(service, 'getPointsSummary').mockResolvedValue({
        balance: 150,
        expiringPoints: 0,
        expiringOn: null,
        expiredPointsTotal: 0,
      });

      const res = await controller.getSummary(mockReq);

      expect(spy).toHaveBeenCalledWith('authed-user-123');
      expect(res.balance).toBe(150);
    });

    it('GET /balance should extract req.user.id and call getPointsSummary', async () => {
      const spy = jest.spyOn(service, 'getPointsSummary').mockResolvedValue({
        balance: 200,
        expiringPoints: 50,
        expiringOn: null,
        expiredPointsTotal: 0,
      });

      const res = await controller.getBalance(mockReq);

      expect(spy).toHaveBeenCalledWith('authed-user-123');
      expect(res.balance).toBe(200);
    });

    it('GET /history should pass req.user.id and limit to getPointsHistory', async () => {
      const spy = jest.spyOn(service, 'getPointsHistory').mockResolvedValue({
        history: [],
        total: 0,
      });

      const res = await controller.getHistory(mockReq, 25);

      expect(spy).toHaveBeenCalledWith('authed-user-123', 25);
      expect(res.total).toBe(0);
    });

    it('GET /referral-code should call getOrCreateReferralCode with req.user.id', async () => {
      const spy = jest.spyOn(service, 'getOrCreateReferralCode').mockResolvedValue({
        referralCode: 'STARQMYCODE',
      });

      const res = await controller.getReferralCode(mockReq);

      expect(spy).toHaveBeenCalledWith('authed-user-123');
      expect(res.referralCode).toBe('STARQMYCODE');
    });

    it('GET /referrals and GET /referral-summary should call getReferralSummary with req.user.id', async () => {
      const spy = jest.spyOn(service, 'getReferralSummary').mockResolvedValue({
        referralCode: 'STARQMYCODE',
        totalReferrals: 0,
        successfulReferrals: 0,
        pendingReferrals: 0,
        pointsPerSuccessfulReferral: 100,
        totalPointsEarned: 0,
        referrals: [],
      });

      const res1 = await controller.getReferrals(mockReq);
      const res2 = await controller.getReferralSummary(mockReq);

      expect(spy).toHaveBeenNthCalledWith(1, 'authed-user-123');
      expect(spy).toHaveBeenNthCalledWith(2, 'authed-user-123');
      expect(res1.referralCode).toBe('STARQMYCODE');
      expect(res2.referralCode).toBe('STARQMYCODE');
    });
  });
});
