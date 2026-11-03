import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PartnerStatus } from '@prisma/client';
import { RewardsService } from '../rewards/rewards.service';

@Injectable()
export class PartnersService {
  constructor(
    private prisma: PrismaService,
    private rewardsService: RewardsService,
  ) {}

  async updateStatus(userId: string, status: PartnerStatus) {
    const partner = await this.prisma.partner.findUnique({
      where: { userId },
    });
    if (!partner) throw new NotFoundException('Partner profile not found');

    return this.prisma.partner.update({
      where: { id: partner.id },
      data: { status },
    });
  }

  async getAssignedBookings(userId: string) {
    const partner = await this.prisma.partner.findUnique({
      where: { userId },
    });
    if (!partner) throw new NotFoundException('Partner profile not found');

    return this.prisma.booking.findMany({
      where: { partnerId: partner.id },
      include: {
        address: true,
        vehicle: true,
        user: { select: { fullName: true, phone: true } },
      },
      orderBy: { scheduledAt: 'asc' },
    });
  }

  async updateBookingStatus(userId: string, bookingId: string, status: any) {
    const partner = await this.prisma.partner.findUnique({
      where: { userId },
    });
    if (!partner) throw new NotFoundException('Partner profile not found');

    const booking = await this.prisma.booking.findFirst({
      where: { id: bookingId, partnerId: partner.id },
    });
    if (!booking) throw new NotFoundException('Booking not found or not assigned to you');

    const allowedTransitions: Record<string, string[]> = {
      'PARTNER_ASSIGNED': ['PARTNER_ON_THE_WAY'],
      'PARTNER_ON_THE_WAY': ['PARTNER_ARRIVED'],
      'PARTNER_ARRIVED': ['SERVICE_STARTED'],
      'SERVICE_STARTED': ['SERVICE_IN_PROGRESS'],
      'SERVICE_IN_PROGRESS': ['SERVICE_COMPLETED'],
      'SERVICE_COMPLETED': ['COMPLETED'],
    };

    const allowedNext = allowedTransitions[booking.status] || [];
    if (!allowedNext.includes(status)) {
      throw new BadRequestException(`Invalid state transition from ${booking.status} to ${status}`);
    }

    const updated = await this.prisma.booking.update({
      where: { id: bookingId },
      data: { status },
    });
    
    await this.prisma.bookingStatusHistory.create({
        data: {
            bookingId: booking.id,
            status: status
        }
    });
    
    if (status === 'COMPLETED' || status === 'CANCELLED') {
       await this.prisma.partner.update({
           where: { id: partner.id },
           data: { status: 'AVAILABLE' }
       });
    }

    if (status === 'COMPLETED') {
      try {
        await this.rewardsService.awardReferralRewardIfEligible(booking.id);
      } catch (err: any) {
        console.warn('Referral reward check error on booking completion:', err?.message || err);
      }
    }

    return updated;
  }

  async updateLocation(userId: string, data: { latitude: number; longitude: number; accuracy?: number; heading?: number; speed?: number }) {
    const partner = await this.prisma.partner.findUnique({
      where: { userId },
    });
    if (!partner) throw new NotFoundException('Partner profile not found');

    // Find active booking
    const activeBooking = await this.prisma.booking.findFirst({
      where: { 
        partnerId: partner.id,
        status: {
          in: ['PARTNER_ASSIGNED', 'PARTNER_ON_THE_WAY', 'PARTNER_ARRIVED', 'SERVICE_STARTED', 'SERVICE_IN_PROGRESS']
        }
      }
    });

    if (!activeBooking) {
      throw new NotFoundException('No active booking found. Tracking not allowed.');
    }

    // Validate coordinates
    if (typeof data.latitude !== 'number' || typeof data.longitude !== 'number' || 
        data.latitude < -90 || data.latitude > 90 || data.longitude < -180 || data.longitude > 180) {
      throw new Error('Invalid coordinates');
    }

    return this.prisma.partnerLocation.create({
      data: {
        partnerId: partner.id,
        bookingId: activeBooking.id,
        latitude: data.latitude,
        longitude: data.longitude,
        accuracy: data.accuracy,
        heading: data.heading,
        speed: data.speed,
      }
    });
  }
}
