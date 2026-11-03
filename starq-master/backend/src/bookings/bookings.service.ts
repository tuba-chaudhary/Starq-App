import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { PricingService } from '../pricing/pricing.service';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const Razorpay = require('razorpay');

@Injectable()
export class BookingsService {
  private razorpay;
  private idempotencyStore = new Map<string, { response: any; timestamp: number }>();

  constructor(private prisma: PrismaService, private pricingService: PricingService) {
    const key_id = process.env.RAZORPAY_KEY_ID || 'dummy_key_id';
    const key_secret = process.env.RAZORPAY_KEY_SECRET || 'dummy_key_secret';
    
    if (key_id !== 'dummy_key_id' && !key_id.includes('placeholder')) {
      try {
        this.razorpay = new Razorpay({ key_id, key_secret });
      } catch (e) {
        console.warn('Razorpay init fallback to test mode:', e);
      }
    }
  }

  async create(userId: string, createBookingDto: CreateBookingDto) {
    const rawIdempotencyKey = createBookingDto.idempotencyKey?.trim();
    if (rawIdempotencyKey) {
      const cached = this.idempotencyStore.get(rawIdempotencyKey);
      if (cached && Date.now() - cached.timestamp < 24 * 60 * 60 * 1000) {
        return cached.response;
      }
    }

    let { vehicleId, serviceId, addonIds = [], addressId, scheduledAt } = createBookingDto;

    // 1. Resolve Address
    let address;
    if (addressId && addressId.trim().length > 0) {
      address = await this.prisma.address.findFirst({
        where: { id: addressId.trim(), userId }
      });
      if (!address) {
        throw new BadRequestException('Selected address not found or does not belong to you');
      }
      if (address.line2 && address.line2.startsWith('[ARCHIVED]')) {
        throw new BadRequestException('Selected address has been archived');
      }
    } else if (createBookingDto.addressData) {
      const { line1, city, line2, state, zipCode, latitude, longitude } = createBookingDto.addressData;
      if (!line1 || !line1.trim() || !city || !city.trim()) {
        throw new BadRequestException('Address line1 and city are required for new address');
      }
      address = await this.prisma.address.create({
        data: {
          userId,
          line1: line1.trim(),
          line2: line2?.trim() || 'Service Location',
          city: city.trim(),
          state: state?.trim() || 'Uttar Pradesh',
          zipCode: zipCode?.trim() || '',
          latitude: latitude ?? 28.6280,
          longitude: longitude ?? 77.3649,
        }
      });
    } else {
      throw new BadRequestException('A valid addressId or addressData is required to create a booking');
    }
    addressId = address.id;

    // 2. Resolve Service
    const cleanServiceId = serviceId?.trim();
    if (!cleanServiceId) {
      throw new BadRequestException('A valid serviceId is required to create a booking');
    }

    const service = await this.prisma.service.findUnique({
      where: { id: cleanServiceId },
      include: { variants: true }
    });
    if (!service) {
      throw new BadRequestException(`Service with id '${cleanServiceId}' not found`);
    }

    if (!service.variants || service.variants.length === 0) {
      throw new BadRequestException(`Service '${service.name}' has no variants configured`);
    }

    // 3. Resolve Vehicle (Category-Aware)
    let vehicle;
    if (vehicleId && vehicleId.trim().length > 0) {
      vehicle = await this.prisma.vehicle.findFirst({
        where: { id: vehicleId.trim(), userId },
        include: { vehicleType: true },
      });
      if (!vehicle) {
        throw new BadRequestException('Selected vehicle was not found or does not belong to user');
      }
    } else {
      // Find compatible vehicle matching service category
      const targetCategory = (service.category || 'CAR').toUpperCase();
      vehicle = await this.prisma.vehicle.findFirst({
        where: {
          userId,
          vehicleType: { name: targetCategory },
        },
        include: { vehicleType: true },
      });
      if (!vehicle) {
        throw new BadRequestException('Please select or add a vehicle to complete your booking');
      }
    }
    vehicleId = vehicle.id;

    // Verify vehicle category compatibility
    if (vehicle.vehicleType && service.category) {
      const vehicleCategory = vehicle.vehicleType.name.toUpperCase();
      const serviceCategory = service.category.toUpperCase();
      if (vehicleCategory !== serviceCategory) {
        throw new BadRequestException(
          `Service '${service.name}' (${service.category}) is not compatible with vehicle type '${vehicle.vehicleType.name}'`
        );
      }
    }

    serviceId = service.id;

    // 4. Check for duplicate pending payment booking (idempotency guard)
    const scheduledDate = scheduledAt ? new Date(scheduledAt) : new Date();
    const cleanDate = isNaN(scheduledDate.getTime()) ? new Date() : scheduledDate;

    const recentPending = await this.prisma.booking.findFirst({
      where: {
        userId,
        vehicleId,
        addressId,
        status: 'PENDING_PAYMENT',
        scheduledAt: cleanDate,
        items: {
          some: {
            serviceVariant: {
              serviceId: cleanServiceId,
            },
          },
        },
        createdAt: {
          gte: new Date(Date.now() - 5 * 60 * 1000),
        },
      },
      include: {
        payments: {
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
    });

    if (recentPending && recentPending.payments.length > 0 && recentPending.payments[0].status === 'created') {
      const existingPayment = recentPending.payments[0];
      const verifiedQuote = await this.pricingService.getQuote(userId, { vehicleId, serviceId, addonIds });
      const duplicateRes = {
        booking: recentPending,
        payment: existingPayment,
        orderId: existingPayment.providerOrderId,
        quote: verifiedQuote,
      };
      if (rawIdempotencyKey) {
        this.idempotencyStore.set(rawIdempotencyKey, { response: duplicateRes, timestamp: Date.now() });
      }
      return duplicateRes;
    }

    // 5. Get strictly verified Quote
    const quote = await this.pricingService.getQuote(userId, { vehicleId, serviceId, addonIds });

    // 6. Create Booking and relations in a Transaction
    const booking = await this.prisma.$transaction(async (tx) => {
      const b = await tx.booking.create({
        data: {
          userId,
          vehicleId,
          addressId,
          status: 'PENDING_PAYMENT',
          totalAmount: quote.total,
          scheduledAt: cleanDate,
        }
      });

      const s = await tx.service.findUnique({
        where: { id: serviceId },
        include: { variants: true }
      });
      const variant = s.variants[0];

      await tx.bookingItem.create({
        data: {
          bookingId: b.id,
          serviceVariantId: variant.id,
          priceAtBooking: quote.basePrice,
        }
      });

      for (const addon of quote.addons) {
        await tx.bookingAddon.create({
          data: {
            bookingId: b.id,
            serviceAddonId: addon.id,
            priceAtBooking: addon.price
          }
        });
      }

      return b;
    });

    // 6. Create Razorpay Order
    let razorpayOrderId = null;
    if (this.razorpay) {
      try {
        const order = await this.razorpay.orders.create({
          amount: Math.round(quote.total * 100), // in paise
          currency: 'INR',
          receipt: booking.id.slice(0, 40),
        });
        razorpayOrderId = order.id;
      } catch (err) {
        console.warn("Razorpay live order creation failed, fallback to mock order:", err?.message || err);
        razorpayOrderId = 'order_mock_' + booking.id;
      }
    } else {
      razorpayOrderId = 'order_mock_' + booking.id;
    }

    // 7. Save Payment record
    const payment = await this.prisma.payment.create({
      data: {
        bookingId: booking.id,
        amount: quote.total,
        currency: 'INR',
        status: 'created',
        provider: 'razorpay',
        providerOrderId: razorpayOrderId
      }
    });

    const responsePayload = { booking, payment, orderId: razorpayOrderId, quote };
    if (rawIdempotencyKey) {
      this.idempotencyStore.set(rawIdempotencyKey, { response: responsePayload, timestamp: Date.now() });
    }
    return responsePayload;
  }

  findAll(userId: string) {
    return this.prisma.booking.findMany({
      where: { userId },
      include: {
        vehicle: true,
        address: true,
        items: { include: { serviceVariant: { include: { service: true } } } },
        addons: { include: { serviceAddon: true } },
        partner: true,
        payments: true,
      },
      orderBy: { createdAt: 'desc' }
    });
  }

  async findOne(id: string, userId?: string) {
    const where: any = { id };
    if (userId) where.userId = userId;

    const booking = await this.prisma.booking.findFirst({
      where,
      include: {
        vehicle: true,
        address: true,
        items: { include: { serviceVariant: { include: { service: true } } } },
        addons: { include: { serviceAddon: true } },
        partner: true,
        payments: true,
        history: { orderBy: { createdAt: 'asc' } }
      }
    });

    if (!booking) throw new NotFoundException('Booking not found');
    return booking;
  }

  async getPartnerLocation(bookingId: string, userId: string) {
    const booking = await this.prisma.booking.findFirst({
      where: { id: bookingId, userId },
      include: {
        partner: {
          include: {
            user: { select: { fullName: true, phone: true } }
          }
        },
        vehicle: true,
        address: true,
        items: { include: { serviceVariant: { include: { service: true } } } },
      }
    });
    if (!booking) throw new NotFoundException('Booking not found');

    const activeStatuses = ['PARTNER_ASSIGNED', 'PARTNER_ON_THE_WAY', 'PARTNER_ARRIVED', 'SERVICE_STARTED', 'SERVICE_IN_PROGRESS'];
    const isEligible = activeStatuses.includes(booking.status) && !!booking.partnerId;

    let loc: any = null;
    let isLive = false;
    let reason = '';

    if (!booking.partnerId) {
      reason = 'Partner assignment in progress. Live tracking will activate once assigned.';
    } else if (!isEligible) {
      reason = booking.status === 'COMPLETED'
        ? 'Service completed. Live tracking has ended.'
        : `Service is currently ${booking.status.replace(/_/g, ' ')}. Live GPS is not active.`;
    } else {
      loc = await this.prisma.partnerLocation.findFirst({
        where: { partnerId: booking.partnerId },
        orderBy: { recordedAt: 'desc' },
      });

      if (!loc) {
        reason = 'Partner is assigned. Waiting for partner device to broadcast live GPS.';
      } else {
        const recordedDate = loc.recordedAt ? new Date(loc.recordedAt) : new Date();
        const ageSeconds = (Date.now() - recordedDate.getTime()) / 1000;
        isLive = !isNaN(ageSeconds) ? ageSeconds <= 300 : true; // Fresh within 5 minutes
        if (!isLive) {
          reason = `Partner GPS signal temporarily offline (last seen ${Math.round(ageSeconds / 60)} min ago).`;
        }
      }
    }

    const serviceName = booking.items?.[0]?.serviceVariant?.service?.name ?? 'STARQ Doorstep Wash';
    const locRecorded = loc?.recordedAt ? (typeof loc.recordedAt === 'string' ? loc.recordedAt : loc.recordedAt.toISOString()) : new Date().toISOString();

    return {
      success: true,
      available: isLive,
      latitude: loc && isLive ? loc.latitude : undefined,
      longitude: loc && isLive ? loc.longitude : undefined,
      recordedAt: loc && isLive ? locRecorded : undefined,
      data: {
        booking: {
          id: booking.id,
          bookingNumber: `STQ-${booking.id.substring(0, 8).toUpperCase()}`,
          status: booking.status,
          statusDisplay: booking.status ? booking.status.replace(/_/g, ' ') : 'CONFIRMED',
          scheduledDate: booking.scheduledAt ? booking.scheduledAt.toISOString() : new Date().toISOString(),
          scheduledTimeSlot: 'Scheduled Slot',
          service: { name: serviceName },
          partner: booking.partner ? {
            id: booking.partner.id,
            name: booking.partner.user?.fullName || 'STARQ Specialist',
            phone: booking.partner.user?.phone,
            rating: booking.partner.rating || 5.0,
            completedJobs: booking.partner.totalCompletedJobs || 0,
          } : null,
        },
        location: (loc && isLive) ? {
          latitude: loc.latitude,
          longitude: loc.longitude,
          recorded_at: locRecorded,
          heading: loc.heading,
          speed: loc.speed,
        } : null,
        tracking_active: isLive,
        reason: reason,
      }
    };
  }
}
