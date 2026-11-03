import { Test, TestingModule } from '@nestjs/testing';
import { VehiclesService } from './vehicles.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotFoundException } from '@nestjs/common';

describe('VehiclesService', () => {
  let service: VehiclesService;
  let prisma: PrismaService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        VehiclesService,
        {
          provide: PrismaService,
          useValue: {
            vehicle: {
              create: jest.fn(),
              findMany: jest.fn(),
              findFirst: jest.fn(),
              update: jest.fn(),
              delete: jest.fn(),
            },
          },
        },
      ],
    }).compile();

    service = module.get<VehiclesService>(VehiclesService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('should create a vehicle linked to the user and normalized license plate', async () => {
      const dto = { vehicleTypeId: 'type1', make: 'Honda', model: 'City', category: 'Sedan', licensePlate: 'ka01 ab 1234' };
      jest.spyOn(prisma.vehicle, 'create').mockResolvedValue({ id: 'v1', userId: 'user1', ...dto, licensePlate: 'KA 01 AB 1234' } as any);
      
      const result = await service.create('user1', dto);
      expect(prisma.vehicle.create).toHaveBeenCalledWith({
        data: {
          userId: 'user1',
          vehicleTypeId: 'type1',
          make: 'Honda',
          model: 'City',
          category: 'Sedan',
          licensePlate: 'KA 01 AB 1234',
        },
        include: {
          vehicleType: true,
        },
      });
      expect(result.id).toEqual('v1');
    });

    it('should throw BadRequestException if license plate format is invalid', async () => {
      const invalidPlates = ['12345678', 'XX01AB1234', 'MHAB1234', 'KA01', 'DL@01#1234'];
      for (const plate of invalidPlates) {
        const dto = { vehicleTypeId: 'type1', make: 'Honda', model: 'City', licensePlate: plate };
        await expect(service.create('user1', dto as any)).rejects.toThrow('Please enter a valid vehicle plate');
      }
    });

    it('should accept and normalize valid vehicle plates including DL 3C and BH series', async () => {
      const validPlates = [
        { input: 'mh 01 ab 1234', expected: 'MH 01 AB 1234' },
        { input: 'DL3CAB1234', expected: 'DL 3C AB 1234' },
        { input: 'ka 05 m 1234', expected: 'KA 05 M 1234' },
        { input: '22BH1234AA', expected: '22 BH 1234 AA' },
      ];
      for (const { input, expected } of validPlates) {
        const dto = { vehicleTypeId: 'type1', make: 'Honda', model: 'City', licensePlate: input };
        jest.spyOn(prisma.vehicle, 'create').mockResolvedValue({ id: 'v1', userId: 'user1', ...dto, licensePlate: expected } as any);
        await service.create('user1', dto as any);
        expect(prisma.vehicle.create).toHaveBeenCalledWith(
          expect.objectContaining({
            data: expect.objectContaining({ licensePlate: expected }),
          }),
        );
      }
    });

    it('should throw BadRequestException if license plate / registration number is missing or empty', async () => {
      const dto = { vehicleTypeId: 'type1', make: 'Honda', model: 'City', licensePlate: '   ' };
      await expect(service.create('user1', dto as any)).rejects.toThrow('Vehicle registration number / license plate is required');
    });

    it('should throw BadRequestException if make/brand is missing or empty', async () => {
      const dto = { vehicleTypeId: 'type1', make: '', brand: '', model: 'City', licensePlate: 'DL01AB1234' };
      await expect(service.create('user1', dto as any)).rejects.toThrow('Vehicle brand / make is required');
    });

    it('should throw BadRequestException if model is missing or empty', async () => {
      const dto = { vehicleTypeId: 'type1', make: 'Honda', model: '  ', licensePlate: 'DL01AB1234' };
      await expect(service.create('user1', dto as any)).rejects.toThrow('Vehicle model is required');
    });
  });

  describe('findOne', () => {
    it('should return vehicle if ownership matches', async () => {
      jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue({ id: 'v1', userId: 'user1' } as any);
      const result = await service.findOne('v1', 'user1');
      expect(result.id).toEqual('v1');
    });

    it('should throw NotFoundException if vehicle not found or belongs to another user', async () => {
      jest.spyOn(prisma.vehicle, 'findFirst').mockResolvedValue(null);
      await expect(service.findOne('v1', 'wrongUser')).rejects.toThrow(NotFoundException);
    });
  });
});
