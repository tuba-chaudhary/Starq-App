import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { PricingService } from './pricing.service';
import { PrismaService } from '../prisma/prisma.service';

describe('PricingService', () => {
  let service: PricingService;
  let prisma: PrismaService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PricingService,
        {
          provide: PrismaService,
          useValue: {
            vehicle: { findFirst: jest.fn() },
            service: { findUnique: jest.fn() },
            serviceAddon: { findMany: jest.fn() },
          },
        },
      ],
    }).compile();

    service = module.get<PricingService>(PricingService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should calculate quote correctly for compatible car vehicle and car service with zero convenience fee', async () => {
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
      id: 'v_car',
      userId: 'u1',
      vehicleType: { name: 'CAR' },
    } as any);

    jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
      id: 's_ext_wash',
      name: 'Exterior Wash',
      category: 'CAR',
      variants: [{ id: 'var_ext', price: 249.0, durationMins: 45 }],
    } as any);

    const quote = await service.getQuote('u1', {
      vehicleId: 'v_car',
      serviceId: 's_ext_wash',
    });

    expect(quote.vehicleId).toBe('v_car');
    expect(quote.serviceId).toBe('s_ext_wash');
    expect(quote.serviceName).toBe('Exterior Wash');
    expect(quote.basePrice).toBe(249.0);
    expect(quote.addonsTotal).toBe(0);
    expect(quote.subtotal).toBe(249.0);
    expect(quote.taxes).toBe(0);
    expect(quote.total).toBe(249.0);
    expect(quote.currency).toBe('INR');
  });

  it('should calculate quote correctly for compatible bike vehicle and bike service with zero convenience fee', async () => {
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
      id: 'v_bike',
      userId: 'u1',
      vehicleType: { name: 'BIKE' },
    } as any);

    jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
      id: 's_bucket_wash',
      name: 'Bucket Wash',
      category: 'BIKE',
      variants: [{ id: 'var_bucket', price: 299.0, durationMins: 20 }],
    } as any);

    const quote = await service.getQuote('u1', {
      vehicleId: 'v_bike',
      serviceId: 's_bucket_wash',
    });

    expect(quote.serviceName).toBe('Bucket Wash');
    expect(quote.basePrice).toBe(299.0);
    expect(quote.total).toBe(299.0);
  });

  it('should reject when car vehicle tries to book bike service', async () => {
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
      id: 'v_car',
      userId: 'u1',
      vehicleType: { name: 'CAR' },
    } as any);

    jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
      id: 's_pressure_wash_bike',
      name: 'Pressure Wash',
      category: 'BIKE',
      variants: [{ id: 'var_press', price: 399.0, durationMins: 30 }],
    } as any);

    await expect(
      service.getQuote('u1', {
        vehicleId: 'v_car',
        serviceId: 's_pressure_wash_bike',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('should reject when bike vehicle tries to book car service', async () => {
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
      id: 'v_bike',
      userId: 'u1',
      vehicleType: { name: 'BIKE' },
    } as any);

    jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
      id: 's_interior_cleaning',
      name: 'Interior Cleaning',
      category: 'CAR',
      variants: [{ id: 'var_int', price: 399.0, durationMins: 60 }],
    } as any);

    await expect(
      service.getQuote('u1', {
        vehicleId: 'v_bike',
        serviceId: 's_interior_cleaning',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('should throw NotFoundException if vehicle not found or does not belong to user', async () => {
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue(null);

    await expect(
      service.getQuote('u1', {
        vehicleId: 'v_foreign',
        serviceId: 's_valid',
      }),
    ).rejects.toThrow(NotFoundException);
  });

  it('should throw NotFoundException if service not found in database', async () => {
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
      id: 'v_car',
      userId: 'u1',
      vehicleType: { name: 'CAR' },
    } as any);

    jest.spyOn(prisma.service, 'findUnique').mockResolvedValue(null);

    await expect(
      service.getQuote('u1', {
        vehicleId: 'v_car',
        serviceId: 's_invalid',
      }),
    ).rejects.toThrow(NotFoundException);
  });

  it('should throw BadRequestException if service has no variants configured', async () => {
    jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
      id: 'v_car',
      userId: 'u1',
      vehicleType: { name: 'CAR' },
    } as any);

    jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
      id: 's_empty',
      name: 'Empty Service',
      category: 'CAR',
      variants: [],
    } as any);

    await expect(
      service.getQuote('u1', {
        vehicleId: 'v_car',
        serviceId: 's_empty',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  describe('Vehicle Category Dynamic Package Pricing', () => {
    it('should price Hatchback packages accurately according to specification', async () => {
      jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
        id: 'v_hb',
        userId: 'u1',
        category: 'HATCHBACK',
        vehicleType: { name: 'CAR' },
      } as any);

      // Silver -> 399
      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000001-0000-4000-8000-000000000001',
        name: 'Exterior Wash',
        category: 'CAR',
        variants: [{ id: 'var1', price: 249 }],
      } as any);
      const silver = await service.getQuote('u1', { vehicleId: 'v_hb', serviceId: 'a0000001-0000-4000-8000-000000000001' });
      expect(silver.basePrice).toBe(399);
      expect(silver.total).toBe(399);
      expect(silver.serviceName).toBe('Silver — Basic Wash');

      // Gold -> 699
      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000002-0000-4000-8000-000000000002',
        name: 'Interior Cleaning',
        category: 'CAR',
        variants: [{ id: 'var2', price: 399 }],
      } as any);
      const gold = await service.getQuote('u1', { vehicleId: 'v_hb', serviceId: 'a0000002-0000-4000-8000-000000000002' });
      expect(gold.basePrice).toBe(699);
      expect(gold.total).toBe(699);
      expect(gold.serviceName).toBe('Gold — Deluxe Wash');

      // Diamond -> 1099
      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000004-0000-4000-8000-000000000004',
        name: 'Premium Wash',
        category: 'CAR',
        variants: [{ id: 'var4', price: 1299 }],
      } as any);
      const diamond = await service.getQuote('u1', { vehicleId: 'v_hb', serviceId: 'a0000004-0000-4000-8000-000000000004' });
      expect(diamond.basePrice).toBe(1099);
      expect(diamond.total).toBe(1099);
      expect(diamond.serviceName).toBe('Diamond — Premium Wash');

      // Platinum -> 2699
      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000003-0000-4000-8000-000000000003',
        name: 'Full Detailing',
        category: 'CAR',
        variants: [{ id: 'var3', price: 999 }],
      } as any);
      const platinum = await service.getQuote('u1', { vehicleId: 'v_hb', serviceId: 'a0000003-0000-4000-8000-000000000003' });
      expect(platinum.basePrice).toBe(2699);
      expect(platinum.total).toBe(2699);
      expect(platinum.serviceName).toBe('Platinum — Deep Cleaning (Interior + Exterior)');
    });

    it('should price Sedan packages accurately according to specification', async () => {
      jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
        id: 'v_sedan',
        userId: 'u1',
        category: 'SEDAN',
        vehicleType: { name: 'CAR' },
      } as any);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000001-0000-4000-8000-000000000001',
        name: 'Exterior Wash',
        category: 'CAR',
        variants: [{ id: 'var1', price: 249 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_sedan', serviceId: 'a0000001-0000-4000-8000-000000000001' })).total).toBe(599);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000002-0000-4000-8000-000000000002',
        name: 'Interior Cleaning',
        category: 'CAR',
        variants: [{ id: 'var2', price: 399 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_sedan', serviceId: 'a0000002-0000-4000-8000-000000000002' })).total).toBe(799);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000004-0000-4000-8000-000000000004',
        name: 'Premium Wash',
        category: 'CAR',
        variants: [{ id: 'var4', price: 1299 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_sedan', serviceId: 'a0000004-0000-4000-8000-000000000004' })).total).toBe(1199);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000003-0000-4000-8000-000000000003',
        name: 'Full Detailing',
        category: 'CAR',
        variants: [{ id: 'var3', price: 999 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_sedan', serviceId: 'a0000003-0000-4000-8000-000000000003' })).total).toBe(3099);
    });

    it('should price MUV packages accurately according to specification', async () => {
      jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
        id: 'v_muv',
        userId: 'u1',
        category: 'MUV',
        vehicleType: { name: 'CAR' },
      } as any);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000001-0000-4000-8000-000000000001',
        name: 'Exterior Wash',
        category: 'CAR',
        variants: [{ id: 'var1', price: 249 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_muv', serviceId: 'a0000001-0000-4000-8000-000000000001' })).total).toBe(699);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000002-0000-4000-8000-000000000002',
        name: 'Interior Cleaning',
        category: 'CAR',
        variants: [{ id: 'var2', price: 399 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_muv', serviceId: 'a0000002-0000-4000-8000-000000000002' })).total).toBe(899);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000004-0000-4000-8000-000000000004',
        name: 'Premium Wash',
        category: 'CAR',
        variants: [{ id: 'var4', price: 1299 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_muv', serviceId: 'a0000004-0000-4000-8000-000000000004' })).total).toBe(1399);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000003-0000-4000-8000-000000000003',
        name: 'Full Detailing',
        category: 'CAR',
        variants: [{ id: 'var3', price: 999 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_muv', serviceId: 'a0000003-0000-4000-8000-000000000003' })).total).toBe(3399);
    });

    it('should price SUV packages accurately according to specification', async () => {
      jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
        id: 'v_suv',
        userId: 'u1',
        category: 'SUV',
        vehicleType: { name: 'CAR' },
      } as any);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000001-0000-4000-8000-000000000001',
        name: 'Exterior Wash',
        category: 'CAR',
        variants: [{ id: 'var1', price: 249 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_suv', serviceId: 'a0000001-0000-4000-8000-000000000001' })).total).toBe(799);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000002-0000-4000-8000-000000000002',
        name: 'Interior Cleaning',
        category: 'CAR',
        variants: [{ id: 'var2', price: 399 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_suv', serviceId: 'a0000002-0000-4000-8000-000000000002' })).total).toBe(999);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000004-0000-4000-8000-000000000004',
        name: 'Premium Wash',
        category: 'CAR',
        variants: [{ id: 'var4', price: 1299 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_suv', serviceId: 'a0000004-0000-4000-8000-000000000004' })).total).toBe(1499);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000003-0000-4000-8000-000000000003',
        name: 'Full Detailing',
        category: 'CAR',
        variants: [{ id: 'var3', price: 999 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_suv', serviceId: 'a0000003-0000-4000-8000-000000000003' })).total).toBe(3599);
    });

    it('should price Luxury Gold, Diamond, Platinum and reject Silver for Luxury', async () => {
      jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
        id: 'v_lux',
        userId: 'u1',
        category: 'LUXURY',
        vehicleType: { name: 'CAR' },
      } as any);

      // Gold -> 1899
      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000002-0000-4000-8000-000000000002',
        name: 'Interior Cleaning',
        category: 'CAR',
        variants: [{ id: 'var2', price: 399 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_lux', serviceId: 'a0000002-0000-4000-8000-000000000002' })).total).toBe(1899);

      // Diamond -> 2599
      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000004-0000-4000-8000-000000000004',
        name: 'Premium Wash',
        category: 'CAR',
        variants: [{ id: 'var4', price: 1299 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_lux', serviceId: 'a0000004-0000-4000-8000-000000000004' })).total).toBe(2599);

      // Platinum -> 5099
      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000003-0000-4000-8000-000000000003',
        name: 'Full Detailing',
        category: 'CAR',
        variants: [{ id: 'var3', price: 999 }],
      } as any);
      expect((await service.getQuote('u1', { vehicleId: 'v_lux', serviceId: 'a0000003-0000-4000-8000-000000000003' })).total).toBe(5099);

      // Silver -> REJECTED
      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000001-0000-4000-8000-000000000001',
        name: 'Exterior Wash',
        category: 'CAR',
        variants: [{ id: 'var1', price: 249 }],
      } as any);
      await expect(
        service.getQuote('u1', { vehicleId: 'v_lux', serviceId: 'a0000001-0000-4000-8000-000000000001' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should reject when selected vehicle category does not match requested category', async () => {
      jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({
        id: 'v_hb',
        userId: 'u1',
        category: 'HATCHBACK',
        vehicleType: { name: 'CAR' },
      } as any);

      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000001-0000-4000-8000-000000000001',
        name: 'Exterior Wash',
        category: 'CAR',
        variants: [{ id: 'var1', price: 249 }],
      } as any);

      await expect(
        service.getQuote('u1', {
          vehicleId: 'v_hb',
          serviceId: 'a0000001-0000-4000-8000-000000000001',
          vehicleCategory: 'SEDAN',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should calculate quote when vehicleId is omitted but vehicleCategory is provided', async () => {
      jest.spyOn(prisma.service, 'findUnique').mockResolvedValue({
        id: 'a0000001-0000-4000-8000-000000000001',
        name: 'Exterior Wash',
        category: 'CAR',
        variants: [{ id: 'var1', price: 249 }],
      } as any);

      const quote = await service.getQuote('u1', {
        serviceId: 'a0000001-0000-4000-8000-000000000001',
        vehicleCategory: 'HATCHBACK',
      });

      expect(quote.vehicleId).toBeNull();
      expect(quote.vehicleCategory).toBe('HATCHBACK');
      expect(quote.basePrice).toBe(399);
      expect(quote.total).toBe(399);
    });
  });
});
