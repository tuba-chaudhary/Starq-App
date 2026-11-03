import { Injectable, NotFoundException, BadRequestException, Logger, Optional } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ApplicationStatus } from '@prisma/client';
import { PrivateStorageService } from '../storage/private-storage.service';

@Injectable()
export class AdminService {
  private readonly logger = new Logger(AdminService.name);

  constructor(
    private prisma: PrismaService,
    private notificationsService: NotificationsService,
    @Optional() private storageService?: PrivateStorageService,
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

  // ==========================================
  // PARTNER APPLICATION VERIFICATION METHODS
  // ==========================================

  async getPartnerApplications(status?: ApplicationStatus) {
    return this.prisma.partnerApplication.findMany({
      where: status ? { status } : undefined,
      include: {
        user: { select: { id: true, fullName: true, phone: true, email: true } },
        reviewedBy: { select: { id: true, fullName: true, email: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getPartnerApplicationDetails(id: string) {
    const application = await this.prisma.partnerApplication.findUnique({
      where: { id },
      include: {
        user: { select: { id: true, fullName: true, phone: true, email: true, roles: true, role: true } },
        reviewedBy: { select: { id: true, fullName: true, email: true } },
      },
    });
    if (!application) throw new NotFoundException('Partner application not found');
    return application;
  }

  async getPartnerApplicationDocument(id: string, type: 'photo' | 'id-proof'): Promise<{ filePath: string; mimeType: string }> {
    const application = await this.prisma.partnerApplication.findUnique({ where: { id } });
    if (!application) throw new NotFoundException('Partner application not found');

    if (!this.storageService) {
      throw new BadRequestException('Storage service is not available');
    }

    const storedFilename = type === 'photo' ? application.profilePhotoPath : application.idDocumentPath;
    const filePath = this.storageService.getPrivateFilePath(storedFilename);

    const ext = storedFilename.toLowerCase();
    let mimeType = 'application/octet-stream';
    if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) mimeType = 'image/jpeg';
    else if (ext.endsWith('.png')) mimeType = 'image/png';
    else if (ext.endsWith('.pdf')) mimeType = 'application/pdf';

    return { filePath, mimeType };
  }

  async approvePartnerApplication(applicationId: string, adminUserId: string) {
    const application = await this.prisma.partnerApplication.findUnique({
      where: { id: applicationId },
      include: { user: true },
    });
    if (!application) throw new NotFoundException('Partner application not found');

    if (application.userId === adminUserId) {
      throw new BadRequestException('Admins cannot approve their own application');
    }

    if (application.status === 'APPROVED') {
      return application;
    }

    const existingRoles = Array.isArray(application.user.roles) ? application.user.roles : [application.user.role];
    const updatedRoles = Array.from(new Set([...existingRoles, 'PARTNER']));

    // Transactional approval: update application, update user roles, and activate Partner model
    const [updatedApp] = await this.prisma.$transaction([
      this.prisma.partnerApplication.update({
        where: { id: applicationId },
        data: {
          status: 'APPROVED',
          rejectionReason: null,
          reviewedAt: new Date(),
          reviewedById: adminUserId,
        },
      }),
      this.prisma.user.update({
        where: { id: application.userId },
        data: {
          roles: updatedRoles as any,
          role: 'PARTNER',
        },
      }),
      this.prisma.partner.upsert({
        where: { userId: application.userId },
        create: {
          userId: application.userId,
          isActive: true,
          status: 'OFFLINE',
          serviceArea: application.city,
        },
        update: {
          isActive: true,
          serviceArea: application.city,
        },
      }),
    ]);

    await this.notificationsService.sendNotification(
      application.userId,
      'Application Approved!',
      'Congratulations! Your STARQ Service Partner account has been approved.',
      'PARTNER_APPROVED',
    );

    return updatedApp;
  }

  async rejectPartnerApplication(applicationId: string, adminUserId: string, rejectionReason: string) {
    if (!rejectionReason || rejectionReason.trim().length === 0) {
      throw new BadRequestException('A rejection reason is mandatory when rejecting a partner application');
    }

    const application = await this.prisma.partnerApplication.findUnique({
      where: { id: applicationId },
    });
    if (!application) throw new NotFoundException('Partner application not found');

    const updated = await this.prisma.partnerApplication.update({
      where: { id: applicationId },
      data: {
        status: 'REJECTED',
        rejectionReason: rejectionReason.trim(),
        reviewedAt: new Date(),
        reviewedById: adminUserId,
      },
    });

    await this.notificationsService.sendNotification(
      application.userId,
      'Application Update',
      `Your partner application requires correction: ${rejectionReason.trim()}`,
      'PARTNER_REJECTED',
    );

    return updated;
  }

  async suspendPartner(applicationId: string, adminUserId: string) {
    const application = await this.prisma.partnerApplication.findUnique({
      where: { id: applicationId },
      include: { user: true },
    });
    if (!application) throw new NotFoundException('Partner application not found');

    const [updatedApp] = await this.prisma.$transaction([
      this.prisma.partnerApplication.update({
        where: { id: applicationId },
        data: {
          status: 'SUSPENDED',
          reviewedAt: new Date(),
          reviewedById: adminUserId,
        },
      }),
      this.prisma.partner.updateMany({
        where: { userId: application.userId },
        data: {
          isActive: false,
          status: 'OFFLINE',
        },
      }),
      this.prisma.user.update({
        where: { id: application.userId },
        data: { role: 'CUSTOMER' },
      }),
    ]);

    return updatedApp;
  }
}
