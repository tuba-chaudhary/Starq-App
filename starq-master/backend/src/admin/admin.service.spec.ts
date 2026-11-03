import { Test, TestingModule } from '@nestjs/testing';
import { AdminService } from './admin.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { NotFoundException, BadRequestException } from '@nestjs/common';

describe('AdminService', () => {
  let service: AdminService;
  let prisma: PrismaService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminService,
        {
          provide: PrismaService,
          useValue: {
            booking: { findMany: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
            partner: { findMany: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
            bookingStatusHistory: { create: jest.fn() },
            $transaction: jest.fn(),
          },
        },
        {
          provide: NotificationsService,
          useValue: { sendNotification: jest.fn() },
        },
      ],
    }).compile();

    service = module.get<AdminService>(AdminService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should list bookings', async () => {
    jest.spyOn(prisma.booking, 'findMany').mockResolvedValue([]);
    expect(await service.getBookings()).toEqual([]);
  });

  it('should list partners', async () => {
    jest.spyOn(prisma.partner, 'findMany').mockResolvedValue([]);
    expect(await service.getPartners()).toEqual([]);
  });

  it('should manually assign a partner', async () => {
    jest.spyOn(prisma.booking, 'findUnique').mockResolvedValueOnce({ id: 'b1', status: 'CONFIRMED' } as any).mockResolvedValueOnce({ id: 'b1', status: 'PARTNER_ASSIGNED' } as any);
    jest.spyOn(prisma.partner, 'findUnique').mockResolvedValue({ id: 'p1', status: 'AVAILABLE' } as any);
    jest.spyOn(prisma, '$transaction').mockResolvedValue([]);

    await service.manualAssignPartner('b1', 'p1');
    expect(prisma.$transaction).toHaveBeenCalled();
  });

  it('should throw if partner is BUSY', async () => {
    jest.spyOn(prisma.booking, 'findUnique').mockResolvedValue({ id: 'b1', status: 'CONFIRMED' } as any);
    jest.spyOn(prisma.partner, 'findUnique').mockResolvedValue({ id: 'p1', status: 'BUSY' } as any);

    await expect(service.manualAssignPartner('b1', 'p1')).rejects.toThrow(BadRequestException);
  });
});
