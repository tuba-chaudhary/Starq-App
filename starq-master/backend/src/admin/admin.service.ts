import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(
    private prisma: PrismaService,
    private notificationsService: NotificationsService,
  ) {}

  async getBookings(status?: string, take: number = 50, skip: number = 0) {
    return this.prisma.booking.findMany({
      where: status ? { status: status as any } : undefined,
      include: {
        user: { select: { id: true, fullName: true, phone: true, email: true } },
        vehicle: true,
        address: true,
        partner: { include: { user: { select: { id: true, fullName: true, phone: true } } } },
        payments: { select: { id: true, status: true, amount: true, provider: true } },
      },
      orderBy: { createdAt: 'desc' },
      take,
      skip,
    });
  }

  async getBookingDetails(id: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        user: { select: { id: true, fullName: true, phone: true, email: true } },
        vehicle: true,
        items: { include: { serviceVariant: { include: { service: true } } } },
        addons: { include: { serviceAddon: true } },
        address: true,
        partner: { include: { user: { select: { fullName: true } } } },
        payments: true,
        history: { orderBy: { createdAt: 'asc' } },
      },
    });
    if (!booking) throw new NotFoundException('Booking not found');
    return booking;
  }

  async getPartners() {
    return this.prisma.partner.findMany({
      include: {
        user: { select: { id: true, fullName: true, phone: true, email: true } },
        bookings: {
          where: { status: { in: ['PARTNER_ASSIGNED', 'PARTNER_ON_THE_WAY', 'PARTNER_ARRIVED', 'SERVICE_STARTED', 'SERVICE_IN_PROGRESS'] } },
          select: { id: true, status: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getPartnerDetails(id: string) {
    const partner = await this.prisma.partner.findUnique({
      where: { id },
      include: {
        user: { select: { id: true, fullName: true, phone: true, email: true } },
        bookings: { orderBy: { createdAt: 'desc' }, take: 10 },
      },
    });
    if (!partner) throw new NotFoundException('Partner not found');
    return partner;
  }

  async manualAssignPartner(bookingId: string, partnerId: string) {
    const booking = await this.prisma.booking.findUnique({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException('Booking not found');
    if (!['CONFIRMED', 'ASSIGNMENT_PENDING'].includes(booking.status)) {
      throw new BadRequestException(`Cannot assign partner to a booking in ${booking.status} state.`);
    }

    const partner = await this.prisma.partner.findUnique({ where: { id: partnerId } });
    if (!partner) throw new NotFoundException('Partner not found');
    if (partner.status === 'BUSY') throw new BadRequestException('Partner is currently BUSY with another booking.');

    await this.prisma.$transaction([
      this.prisma.booking.update({
        where: { id: booking.id },
        data: { status: 'PARTNER_ASSIGNED', partnerId: partner.id },
      }),
      this.prisma.partner.update({
        where: { id: partner.id },
        data: { status: 'BUSY' },
      }),
      this.prisma.bookingStatusHistory.create({
        data: { bookingId: booking.id, status: 'PARTNER_ASSIGNED' },
      }),
    ]);

    await this.notificationsService.sendNotification(partner.userId, 'New Job Assigned', 'An admin assigned a job to you.', 'PARTNER_ASSIGNED', booking.id);
    await this.notificationsService.sendNotification(booking.userId, 'Partner Assigned', 'A partner has been assigned to your booking.', 'PARTNER_ASSIGNED', booking.id);

    return this.getBookingDetails(booking.id);
  }

  async reassignPartner(bookingId: string, newPartnerId: string) {
    const booking = await this.prisma.booking.findUnique({ where: { id: bookingId } });
    if (!booking) throw new NotFoundException('Booking not found');

    const activeStates = ['PARTNER_ASSIGNED', 'PARTNER_ON_THE_WAY', 'PARTNER_ARRIVED'];
    if (!activeStates.includes(booking.status)) {
      throw new BadRequestException(`Cannot reassign booking in ${booking.status} state.`);
    }

    const newPartner = await this.prisma.partner.findUnique({ where: { id: newPartnerId } });
    if (!newPartner) throw new NotFoundException('New partner not found');
    if (newPartner.status === 'BUSY') throw new BadRequestException('New partner is currently BUSY.');

    const oldPartnerId = booking.partnerId;

    const txs: any[] = [
      this.prisma.booking.update({
        where: { id: booking.id },
        data: { status: 'PARTNER_ASSIGNED', partnerId: newPartner.id },
      }),
      this.prisma.partner.update({
        where: { id: newPartner.id },
        data: { status: 'BUSY' },
      }),
      this.prisma.bookingStatusHistory.create({
        data: { bookingId: booking.id, status: 'PARTNER_ASSIGNED', notes: 'Reassigned by Admin' },
      }),
    ];

    if (oldPartnerId) {
      txs.push(
        this.prisma.partner.update({
          where: { id: oldPartnerId },
          data: { status: 'AVAILABLE' },
        })
      );
    }

    await this.prisma.$transaction(txs);

    await this.notificationsService.sendNotification(newPartner.userId, 'New Job Assigned', 'An admin assigned a job to you.', 'PARTNER_ASSIGNED', booking.id);
    await this.notificationsService.sendNotification(booking.userId, 'Partner Assigned', 'A new partner has been assigned to your booking.', 'PARTNER_ASSIGNED', booking.id);
    
    if (oldPartnerId) {
      const oldPartner = await this.prisma.partner.findUnique({ where: { id: oldPartnerId } });
      if (oldPartner) {
        await this.notificationsService.sendNotification(oldPartner.userId, 'Job Reassigned', 'A job assigned to you was reassigned.', 'BOOKING_CANCELLED', booking.id);
      }
    }

    return this.getBookingDetails(booking.id);
  }

  async cancelBooking(bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { payments: true },
    });
    if (!booking) throw new NotFoundException('Booking not found');

    const uncancelable = ['SERVICE_STARTED', 'SERVICE_IN_PROGRESS', 'SERVICE_COMPLETED', 'COMPLETED', 'CANCELLED', 'REFUNDED'];
    if (uncancelable.includes(booking.status)) {
      throw new BadRequestException(`Cannot cancel booking in ${booking.status} state.`);
    }

    const hasSuccessfulPayment = booking.payments.some((p) => p.status === 'captured');
    const newStatus = hasSuccessfulPayment ? 'REFUND_PENDING' : 'CANCELLED';

    const txs: any[] = [
      this.prisma.booking.update({
        where: { id: booking.id },
        data: { status: newStatus },
      }),
      this.prisma.bookingStatusHistory.create({
        data: { bookingId: booking.id, status: newStatus, notes: 'Cancelled by Admin' },
      }),
    ];

    if (booking.partnerId) {
      txs.push(
        this.prisma.partner.update({
          where: { id: booking.partnerId },
          data: { status: 'AVAILABLE' },
        })
      );
    }

    await this.prisma.$transaction(txs);

    await this.notificationsService.sendNotification(booking.userId, 'Booking Cancelled', `Your booking has been ${newStatus.replace('_', ' ').toLowerCase()}.`, newStatus, booking.id);

    if (booking.partnerId) {
      const partner = await this.prisma.partner.findUnique({ where: { id: booking.partnerId } });
      if (partner) {
        await this.notificationsService.sendNotification(partner.userId, 'Job Cancelled', 'An assigned job was cancelled.', 'BOOKING_CANCELLED', booking.id);
      }
    }

    return this.getBookingDetails(booking.id);
  }
}
