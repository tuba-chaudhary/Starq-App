import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { PrismaService } from '../prisma/prisma.service';
import { PricingService } from '../pricing/pricing.service';

jest.mock('razorpay', () => {
  return jest.fn().mockImplementation(() => {
    return {
      orders: {
        create: jest.fn().mockResolvedValue({ id: 'order_mock_b1' })
      }
    };
  });
});

describe('BookingsService', () => {
  let service: BookingsService;
  let prisma: PrismaService;
  let pricing: PricingService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        {
          provide: PrismaService,
          useValue: {
            address: { findFirst: jest.fn(), create: jest.fn() },
            vehicle: { findFirst: jest.fn(), create: jest.fn() },
            vehicleType: { findFirst: jest.fn(), create: jest.fn() },
            service: { findUnique: jest.fn(), findFirst: jest.fn() },
            booking: { findFirst: jest.fn() },
            partnerLocation: { findFirst: jest.fn() },
            $transaction: jest.fn(),
            payment: { create: jest.fn() },
          },
        },
        {
          provide: PricingService,
          useValue: {
            getQuote: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<BookingsService>(BookingsService);
    prisma = module.get<PrismaService>(PrismaService);
    pricing = module.get<PricingService>(PricingService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should throw BadRequestException if addressId is not found or does not belong to user (foreign address)', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue(null);

    await expect(service.create('u1', { 
      vehicleId: 'v1', 
      serviceId: 's1', 
      addressId: 'foreign_or_invalid_addr', 
      scheduledAt: new Date().toISOString() 
    })).rejects.toThrow(BadRequestException);
  });

  it('should throw BadRequestException if addressId is archived', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue({
      id: 'a1_archived',
      userId: 'u1',
      line2: '[ARCHIVED] Home',
    } as any);

    await expect(service.create('u1', { 
      vehicleId: 'v1', 
      serviceId: 's1', 
      addressId: 'a1_archived', 
      scheduledAt: new Date().toISOString() 
    })).rejects.toThrow(BadRequestException);
  });

  it('should throw BadRequestException if both addressId and addressData are missing', async () => {
    await expect(service.create('u1', { 
      vehicleId: 'v1', 
      serviceId: 's1', 
      scheduledAt: new Date().toISOString() 
    })).rejects.toThrow(BadRequestException);
  });

  it('should throw BadRequestException if addressData is missing required line1 or city', async () => {
    await expect(service.create('u1', { 
      vehicleId: 'v1', 
      serviceId: 's1', 
      scheduledAt: new Date().toISOString(),
      addressData: { line1: '', city: 'Noida' }
    })).rejects.toThrow(BadRequestException);
  });

  it('should create address inline and succeed when valid addressData is provided', async () => {
    jest.spyOn(prisma.address, 'create').mockResolvedValue({ id: 'a_inline', userId: 'u1' } as any);
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({ id: 'v1', userId: 'u1' } as any);
    jest.spyOn((prisma as any).service, 'findUnique').mockResolvedValue({ id: 's1', variants: [{ id: 'sv1', price: 100 }] } as any);
    jest.spyOn(pricing, 'getQuote').mockResolvedValue({ total: 100, addons: [] } as any);
    jest.spyOn(prisma, '$transaction').mockResolvedValue({ id: 'b1' } as any);
    jest.spyOn(prisma.payment, 'create').mockResolvedValue({ id: 'p1' } as any);

    const result = await service.create('u1', { 
      vehicleId: 'v1', 
      serviceId: 's1', 
      scheduledAt: new Date().toISOString(),
      addressData: { line1: 'Sector 50', city: 'Noida' }
    });
    expect(result.booking.id).toEqual('b1');
    expect(prisma.address.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ line1: 'Sector 50', city: 'Noida', userId: 'u1' })
    }));
  });

  it('should create booking and initiate razorpay', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue({ id: 'a1', userId: 'u1' } as any);
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({ id: 'v1', userId: 'u1' } as any);
    jest.spyOn((prisma as any).service, 'findUnique').mockResolvedValue({ id: 's1', variants: [{ id: 'sv1', price: 100 }] } as any);
    jest.spyOn(pricing, 'getQuote').mockResolvedValue({
      total: 100, addons: []
    } as any);
    jest.spyOn(prisma, '$transaction').mockResolvedValue({ id: 'b1' } as any);
    jest.spyOn(prisma.payment, 'create').mockResolvedValue({ id: 'p1' } as any);

    const result = await service.create('u1', { 
      vehicleId: 'v1', 
      serviceId: 's1', 
      addressId: 'a1', 
      scheduledAt: new Date().toISOString() 
    });

    expect(result.orderId).toEqual('order_mock_b1');
    expect(result.payment.id).toEqual('p1');
    expect(result.booking.id).toEqual('b1');
  });

  it('should throw BadRequestException if serviceId is missing or empty', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue({ id: 'a1', userId: 'u1' } as any);
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({ id: 'v1', userId: 'u1' } as any);

    await expect(service.create('u1', { 
      vehicleId: 'v1', 
      serviceId: '', 
      addressId: 'a1', 
      scheduledAt: new Date().toISOString() 
    })).rejects.toThrow(BadRequestException);
  });

  it('should throw BadRequestException if serviceId does not exist in database', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue({ id: 'a1', userId: 'u1' } as any);
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({ id: 'v1', userId: 'u1' } as any);
    jest.spyOn((prisma as any).service, 'findUnique').mockResolvedValue(null);

    await expect(service.create('u1', { 
      vehicleId: 'v1', 
      serviceId: 'nonexistent_service_id', 
      addressId: 'a1', 
      scheduledAt: new Date().toISOString() 
    })).rejects.toThrow(BadRequestException);
  });

  it('should throw BadRequestException if service has no variants configured', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue({ id: 'a1', userId: 'u1' } as any);
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({ id: 'v1', userId: 'u1' } as any);
    jest.spyOn((prisma as any).service, 'findUnique').mockResolvedValue({ id: 's1', name: 'Wash', variants: [] } as any);

    await expect(service.create('u1', { 
      vehicleId: 'v1', 
      serviceId: 's1', 
      addressId: 'a1', 
      scheduledAt: new Date().toISOString() 
    })).rejects.toThrow(BadRequestException);
  });

  it('should throw BadRequestException if vehicleId is provided but does not belong to user', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue({ id: 'a1', userId: 'u1' } as any);
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue(null);

    await expect(service.create('u1', { 
      vehicleId: 'foreign_vehicle_id', 
      serviceId: 's1', 
      addressId: 'a1', 
      scheduledAt: new Date().toISOString() 
    })).rejects.toThrow(BadRequestException);
  });

  it('should reject booking if car vehicle is paired with bike service', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue({ id: 'a1', userId: 'u1' } as any);
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
      id: 'v_car',
      userId: 'u1',
      vehicleType: { name: 'CAR' },
    } as any);
    jest.spyOn((prisma as any).service, 'findUnique').mockResolvedValue({
      id: 's_bike',
      name: 'Bucket Wash',
      category: 'BIKE',
      variants: [{ id: 'var_b', price: 299 }],
    } as any);

    await expect(service.create('u1', { 
      vehicleId: 'v_car', 
      serviceId: 's_bike', 
      addressId: 'a1', 
      scheduledAt: new Date().toISOString() 
    })).rejects.toThrow(BadRequestException);
  });

  it('should reject booking if bike vehicle is paired with car service', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue({ id: 'a1', userId: 'u1' } as any);
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
      id: 'v_bike',
      userId: 'u1',
      vehicleType: { name: 'BIKE' },
    } as any);
    jest.spyOn((prisma as any).service, 'findUnique').mockResolvedValue({
      id: 's_car',
      name: 'Exterior Wash',
      category: 'CAR',
      variants: [{ id: 'var_c', price: 249 }],
    } as any);

    await expect(service.create('u1', { 
      vehicleId: 'v_bike', 
      serviceId: 's_car', 
      addressId: 'a1', 
      scheduledAt: new Date().toISOString() 
    })).rejects.toThrow(BadRequestException);
  });

  it('should ensure booking total and payment record amount strictly match the authoritative quote total', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue({ id: 'a1', userId: 'u1' } as any);
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
      id: 'v_car',
      userId: 'u1',
      vehicleType: { name: 'CAR' },
    } as any);
    jest.spyOn((prisma as any).service, 'findUnique').mockResolvedValue({
      id: 's_detailing',
      name: 'Full Detailing',
      category: 'CAR',
      variants: [{ id: 'var_det', price: 999.0 }],
    } as any);

    const authoritativeQuote = {
      vehicleId: 'v_car',
      serviceId: 's_detailing',
      serviceName: 'Full Detailing',
      basePrice: 999.0,
      addons: [],
      addonsTotal: 0,
      subtotal: 999.0,
      taxes: 0,
      total: 999.0,
      currency: 'INR',
    };
    jest.spyOn(pricing, 'getQuote').mockResolvedValue(authoritativeQuote as any);

    let createdBookingData: any = null;
    jest.spyOn(prisma, '$transaction').mockImplementation(async (cb: any) => {
      const mockTx = {
        booking: {
          create: jest.fn().mockImplementation(({ data }) => {
            createdBookingData = data;
            return { id: 'booking_full_det_1', ...data };
          }),
        },
        service: {
          findUnique: jest.fn().mockResolvedValue({
            id: 's_detailing',
            variants: [{ id: 'var_det', price: 999.0 }],
          }),
        },
        bookingItem: { create: jest.fn() },
        bookingAddon: { create: jest.fn() },
      };
      return cb(mockTx);
    });

    let createdPaymentData: any = null;
    jest.spyOn(prisma.payment, 'create').mockImplementation((async ({ data }: any) => {
      createdPaymentData = data;
      return { id: 'pay_rec_1', ...data };
    }) as any);

    const result = await service.create('u1', { 
      vehicleId: 'v_car', 
      serviceId: 's_detailing', 
      addressId: 'a1', 
      scheduledAt: new Date().toISOString() 
    });

    // Authoritative quote total
    expect(authoritativeQuote.total).toBe(999.0);
    // Booking record total amount
    expect(createdBookingData.totalAmount).toBe(999.0);
    expect(result.booking.totalAmount).toBe(999.0);
    // Payment record amount
    expect(createdPaymentData.amount).toBe(999.0);
    expect(result.payment.amount).toBe(999.0);
  });

  it('getPartnerLocation should return available false if booking status not active', async () => {
    jest.spyOn(prisma.booking, 'findFirst').mockResolvedValue({ id: 'b1', status: 'CONFIRMED' } as any);
    const result = await service.getPartnerLocation('b1', 'u1');
    expect(result.available).toBe(false);
  });

  it('getPartnerLocation should return location if available', async () => {
    jest.spyOn(prisma.booking, 'findFirst').mockResolvedValue({ id: 'b1', partnerId: 'p1', status: 'SERVICE_STARTED' } as any);
    jest.spyOn(prisma.partnerLocation, 'findFirst').mockResolvedValue({ latitude: 12, longitude: 34 } as any);
    const result = await service.getPartnerLocation('b1', 'u1');
    expect(result.available).toBe(true);
    expect(result.latitude).toBe(12);
  });

  it('should return existing booking idempotently when duplicate idempotencyKey is submitted', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue({ id: 'a1', userId: 'u1' } as any);
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
      id: 'v_car',
      userId: 'u1',
      vehicleType: { name: 'CAR' },
    } as any);
    jest.spyOn((prisma as any).service, 'findUnique').mockResolvedValue({
      id: 's_car',
      name: 'Exterior Wash',
      category: 'CAR',
      variants: [{ id: 'var_c', price: 249 }],
    } as any);

    const quote = {
      vehicleId: 'v_car',
      serviceId: 's_car',
      serviceName: 'Exterior Wash',
      basePrice: 249.0,
      addons: [],
      addonsTotal: 0,
      subtotal: 249.0,
      taxes: 0,
      total: 249.0,
      currency: 'INR',
    };
    jest.spyOn(pricing, 'getQuote').mockResolvedValue(quote as any);

    let createCallCount = 0;
    jest.spyOn(prisma, '$transaction').mockImplementation(async (cb: any) => {
      createCallCount++;
      const mockTx = {
        booking: {
          create: jest.fn().mockResolvedValue({ id: 'booking_idem_123', totalAmount: 249.0, status: 'PENDING_PAYMENT' }),
        },
        service: {
          findUnique: jest.fn().mockResolvedValue({
            id: 's_car',
            variants: [{ id: 'var_c', price: 249.0 }],
          }),
        },
        bookingItem: { create: jest.fn() },
        bookingAddon: { create: jest.fn() },
      };
      return cb(mockTx);
    });

    jest.spyOn(prisma.payment, 'create').mockResolvedValue({ id: 'pay_idem_123', amount: 249.0 } as any);

    const scheduled = new Date().toISOString();
    const result1 = await service.create('u1', {
      vehicleId: 'v_car',
      serviceId: 's_car',
      addressId: 'a1',
      scheduledAt: scheduled,
      idempotencyKey: 'client-idem-key-test-1',
    });

    const result2 = await service.create('u1', {
      vehicleId: 'v_car',
      serviceId: 's_car',
      addressId: 'a1',
      scheduledAt: scheduled,
      idempotencyKey: 'client-idem-key-test-1',
    });

    expect(result1.booking.id).toBe(result2.booking.id);
    expect(createCallCount).toBe(1);
  });

  it('should reject booking when vehicleId is omitted and user has no vehicle of matching category', async () => {
    jest.spyOn(prisma.address, 'findFirst').mockResolvedValue({ id: 'a1', userId: 'u1' } as any);
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue(null);

    jest.spyOn((prisma as any).service, 'findUnique').mockResolvedValue({
      id: 's_bike_bucket',
      name: 'Bucket Wash',
      category: 'BIKE',
      variants: [{ id: 'var_b', price: 299 }],
    } as any);

    await expect(
      service.create('u1', {
        serviceId: 's_bike_bucket',
        addressId: 'a1',
        scheduledAt: new Date().toISOString(),
      }),
    ).rejects.toThrow('Please select or add a vehicle to complete your booking');
  });
});
