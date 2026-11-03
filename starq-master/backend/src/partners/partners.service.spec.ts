import { Test, TestingModule } from '@nestjs/testing';
import { PartnersService } from './partners.service';
import { PrismaService } from '../prisma/prisma.service';
import { RewardsService } from '../rewards/rewards.service';

describe('PartnersService', () => {
  let service: PartnersService;
  let prisma: PrismaService;
  let rewardsService: RewardsService;

  const mockRewardsService = {
    awardReferralRewardIfEligible: jest.fn().mockResolvedValue({ awarded: true }),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PartnersService,
        {
          provide: PrismaService,
          useValue: {
            partner: { 
              findUnique: jest.fn(),
              update: jest.fn()
            },
            booking: {
              findFirst: jest.fn(),
              findMany: jest.fn(),
              update: jest.fn()
            },
            bookingStatusHistory: {
              create: jest.fn()
            },
            partnerLocation: {
              create: jest.fn()
            }
          },
        },
        {
          provide: RewardsService,
          useValue: mockRewardsService,
        },
      ],
    }).compile();

    service = module.get<PartnersService>(PartnersService);
    prisma = module.get<PrismaService>(PrismaService);
    rewardsService = module.get<RewardsService>(RewardsService);
  });

  it('should throw if partner updates booking not assigned to them', async () => {
    jest.spyOn(prisma.partner, 'findUnique').mockResolvedValue({ id: 'p1', userId: 'u1' } as any);
    jest.spyOn(prisma.booking, 'findFirst').mockResolvedValue(null);

    await expect(service.updateBookingStatus('u1', 'b1', 'SERVICE_STARTED')).rejects.toThrow('Booking not found or not assigned to you');
  });

  it('should update booking status correctly', async () => {
    jest.spyOn(prisma.partner, 'findUnique').mockResolvedValue({ id: 'p1', userId: 'u1' } as any);
    jest.spyOn(prisma.booking, 'findFirst').mockResolvedValue({ id: 'b1', partnerId: 'p1', status: 'PARTNER_ARRIVED' } as any);

    await service.updateBookingStatus('u1', 'b1', 'SERVICE_STARTED');

    expect(prisma.booking.update).toHaveBeenCalledWith({
      where: { id: 'b1' },
      data: { status: 'SERVICE_STARTED' }
    });
  });

  it('should trigger referral reward check when status is updated to COMPLETED', async () => {
    jest.spyOn(prisma.partner, 'findUnique').mockResolvedValue({ id: 'p1', userId: 'u1' } as any);
    jest.spyOn(prisma.booking, 'findFirst').mockResolvedValue({ id: 'b1', partnerId: 'p1', status: 'SERVICE_COMPLETED' } as any);

    await service.updateBookingStatus('u1', 'b1', 'COMPLETED');

    expect(prisma.booking.update).toHaveBeenCalledWith({
      where: { id: 'b1' },
      data: { status: 'COMPLETED' }
    });
    expect(mockRewardsService.awardReferralRewardIfEligible).toHaveBeenCalledWith('b1');
  });

  it('updateLocation should create location if active booking exists', async () => {
    jest.spyOn(prisma.partner, 'findUnique').mockResolvedValue({ id: 'p1', userId: 'u1' } as any);
    jest.spyOn(prisma.booking, 'findFirst').mockResolvedValue({ id: 'b1', partnerId: 'p1', status: 'SERVICE_STARTED' } as any);

    await service.updateLocation('u1', { latitude: 12, longitude: 34 });

    expect(prisma.partnerLocation.create).toHaveBeenCalledWith({
      data: {
        partnerId: 'p1',
        bookingId: 'b1',
        latitude: 12,
        longitude: 34,
        accuracy: undefined,
        heading: undefined,
        speed: undefined,
      }
    });
  });

  it('updateLocation should throw if no active booking', async () => {
    jest.spyOn(prisma.partner, 'findUnique').mockResolvedValue({ id: 'p1', userId: 'u1' } as any);
    jest.spyOn(prisma.booking, 'findFirst').mockResolvedValue(null);

    await expect(service.updateLocation('u1', { latitude: 12, longitude: 34 })).rejects.toThrow('No active booking found. Tracking not allowed.');
  });
});
