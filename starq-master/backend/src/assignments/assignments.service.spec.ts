import { Test, TestingModule } from '@nestjs/testing';
import { AssignmentsService } from './assignments.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

describe('AssignmentsService', () => {
  let service: AssignmentsService;
  let prisma: PrismaService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AssignmentsService,
        {
          provide: PrismaService,
          useValue: {
            booking: { 
              findUnique: jest.fn(),
              update: jest.fn()
            },
            partner: {
              findFirst: jest.fn(),
              update: jest.fn()
            },
            bookingStatusHistory: {
              create: jest.fn()
            },
            $transaction: jest.fn()
          },
        },
        {
          provide: NotificationsService,
          useValue: { sendNotification: jest.fn() }
        }
      ],
    }).compile();

    service = module.get<AssignmentsService>(AssignmentsService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should transition to ASSIGNMENT_PENDING if no partner is available', async () => {
    jest.spyOn(prisma.booking, 'findUnique').mockResolvedValue({ id: 'b1', status: 'CONFIRMED' } as any);
    jest.spyOn(prisma.partner, 'findFirst').mockResolvedValue(null);

    await service.autoAssign('b1');

    expect(prisma.booking.update).toHaveBeenCalledWith({
      where: { id: 'b1' },
      data: { status: 'ASSIGNMENT_PENDING' }
    });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('should assign a partner and transition to PARTNER_ASSIGNED', async () => {
    jest.spyOn(prisma.booking, 'findUnique').mockResolvedValue({ id: 'b1', status: 'CONFIRMED' } as any);
    jest.spyOn(prisma.partner, 'findFirst').mockResolvedValue({ id: 'p1' } as any);

    await service.autoAssign('b1');

    expect(prisma.$transaction).toHaveBeenCalled();
  });
});
