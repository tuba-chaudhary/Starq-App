import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class AssignmentsService {
  private readonly logger = new Logger(AssignmentsService.name);
  
  constructor(private prisma: PrismaService, private notificationsService: NotificationsService) {}

  async autoAssign(bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { address: true }
    });

    if (!booking) return;
    if (booking.status !== 'CONFIRMED') {
      this.logger.log(`Booking ${bookingId} is not in CONFIRMED state. Skipping auto-assign.`);
      return;
    }

    // Transition to ASSIGNMENT_PENDING
    await this.prisma.booking.update({
      where: { id: booking.id },
      data: { status: 'ASSIGNMENT_PENDING' }
    });
    
    await this.prisma.bookingStatusHistory.create({
        data: {
            bookingId: booking.id,
            status: 'ASSIGNMENT_PENDING'
        }
    });

    // Find an available partner
    // In a real app we'd match on city/serviceArea, overlapping bookings.
    // For MVP, find first AVAILABLE partner
    const availablePartner = await this.prisma.partner.findFirst({
      where: { 
        status: 'AVAILABLE',
        isActive: true,
        // (MVP matching logic)
      }
    });

    if (availablePartner) {
      // Assign partner and transition to PARTNER_ASSIGNED
      await this.prisma.$transaction([
        this.prisma.booking.update({
          where: { id: booking.id },
          data: { 
            status: 'PARTNER_ASSIGNED',
            partnerId: availablePartner.id 
          }
        }),
        this.prisma.partner.update({
          where: { id: availablePartner.id },
          data: { status: 'BUSY' } // Prevent overlapping assignments
        }),
        this.prisma.bookingStatusHistory.create({
            data: {
                bookingId: booking.id,
                status: 'PARTNER_ASSIGNED'
            }
        })
      ]);
      
      this.logger.log(`Assigned booking ${booking.id} to partner ${availablePartner.id}`);

      // Send notifications
      await this.notificationsService.sendNotification(
        availablePartner.userId,
        'New Job Assigned',
        'You have been assigned a new job.',
        'PARTNER_ASSIGNED',
        booking.id
      );

      await this.notificationsService.sendNotification(
        booking.userId,
        'Partner Assigned',
        'A partner has been assigned to your booking.',
        'PARTNER_ASSIGNED',
        booking.id
      );

    } else {
      this.logger.log(`No partner available for booking ${booking.id}`);
    }
  }
}
