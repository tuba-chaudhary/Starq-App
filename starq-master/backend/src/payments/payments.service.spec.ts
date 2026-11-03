import { Test, TestingModule } from '@nestjs/testing';
import { PaymentsService } from './payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { AssignmentsService } from '../assignments/assignments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RewardsService } from '../rewards/rewards.service';
import * as crypto from 'crypto';
import { BadRequestException } from '@nestjs/common';

describe('PaymentsService', () => {
  let service: PaymentsService;
  let prisma: PrismaService;
  let assignments: AssignmentsService;
  let rewardsService: RewardsService;

  const mockRewardsService = {
    awardReferralRewardIfEligible: jest.fn().mockResolvedValue({ awarded: true }),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentsService,
        {
          provide: PrismaService,
          useValue: {
            payment: { 
              findFirst: jest.fn(),
              update: jest.fn()
            },
            booking: {
              findUnique: jest.fn(),
              update: jest.fn()
            },
            bookingStatusHistory: {
              create: jest.fn()
            }
          },
        },
        {
          provide: AssignmentsService,
          useValue: {
            autoAssign: jest.fn()
          },
        },
        {
          provide: NotificationsService,
          useValue: { sendNotification: jest.fn() }
        },
        {
          provide: RewardsService,
          useValue: mockRewardsService,
        },
      ],
    }).compile();

    service = module.get<PaymentsService>(PaymentsService);
    prisma = module.get<PrismaService>(PrismaService);
    assignments = module.get<AssignmentsService>(AssignmentsService);
    rewardsService = module.get<RewardsService>(RewardsService);
  });

  afterEach(() => {
    delete process.env.RAZORPAY_WEBHOOK_SECRET;
    delete process.env.RAZORPAY_KEY_SECRET;
  });

  it('verifySignature should throw if RAZORPAY_WEBHOOK_SECRET is missing', () => {
    const originalSecret = process.env.RAZORPAY_WEBHOOK_SECRET;
    delete process.env.RAZORPAY_WEBHOOK_SECRET;
    expect(() => service.verifySignature('body', 'sig')).toThrow(BadRequestException);
    process.env.RAZORPAY_WEBHOOK_SECRET = originalSecret;
  });

  it('verifySignature should return true for valid signature', () => {
    process.env.RAZORPAY_WEBHOOK_SECRET = 'test_secret';
    const body = JSON.stringify({ event: 'payment.captured' });
    const signature = crypto.createHmac('sha256', 'test_secret').update(body).digest('hex');
    
    expect(service.verifySignature(body, signature)).toBe(true);
  });

  it('verifySignature should return false for invalid signature', () => {
    process.env.RAZORPAY_WEBHOOK_SECRET = 'test_secret';
    expect(service.verifySignature('body', 'invalid_sig')).toBe(false);
  });

  it('handleWebhook should process payment.captured idempotently and trigger referral reward check', async () => {
    const mockPayment = { id: 'p1', bookingId: 'b1', status: 'created', providerOrderId: 'order_1' };
    jest.spyOn(prisma.payment, 'findFirst').mockResolvedValue(mockPayment as any);
    jest.spyOn(prisma.payment, 'update').mockResolvedValue(mockPayment as any);
    jest.spyOn(prisma.booking, 'findUnique').mockResolvedValue({ id: 'b1', userId: 'u1' } as any);

    const event = {
      event: 'payment.captured',
      payload: { payment: { entity: { id: 'pay_1', order_id: 'order_1' } } }
    };

    const res = await service.handleWebhook(event);
    
    expect(res.status).toBe('success');
    expect(prisma.payment.update).toHaveBeenCalledWith({
      where: { id: 'p1' },
      data: { status: 'captured', providerPaymentId: 'pay_1' }
    });
    expect(prisma.booking.update).toHaveBeenCalledWith({
      where: { id: 'b1' },
      data: { status: 'CONFIRMED' }
    });
    expect(assignments.autoAssign).toHaveBeenCalledWith('b1');
    expect(mockRewardsService.awardReferralRewardIfEligible).toHaveBeenCalledWith('b1');
  });

  it('handleWebhook should ignore duplicate payment.captured', async () => {
    const mockPayment = { id: 'p1', bookingId: 'b1', status: 'captured', providerOrderId: 'order_1' };
    jest.spyOn(prisma.payment, 'findFirst').mockResolvedValue(mockPayment as any);

    const event = {
      event: 'payment.captured',
      payload: { payment: { entity: { id: 'pay_1', order_id: 'order_1' } } }
    };

    const res = await service.handleWebhook(event);
    
    expect(res.status).toBe('already_processed');
    expect(prisma.payment.update).not.toHaveBeenCalled();
    expect(assignments.autoAssign).not.toHaveBeenCalled();
  });
});
