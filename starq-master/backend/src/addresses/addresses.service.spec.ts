import { Test, TestingModule } from '@nestjs/testing';
import { AddressesService } from './addresses.service';
import { PrismaService } from '../prisma/prisma.service';
import { NotFoundException } from '@nestjs/common';

describe('AddressesService', () => {
  let service: AddressesService;
  let prisma: PrismaService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AddressesService,
        {
          provide: PrismaService,
          useValue: {
            address: {
              create: jest.fn(),
              findMany: jest.fn(),
              findFirst: jest.fn(),
              update: jest.fn(),
              delete: jest.fn(),
            },
            booking: {
              count: jest.fn(),
            },
          },
        },
      ],
    }).compile();

    service = module.get<AddressesService>(AddressesService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('create', () => {
    it('should create an address linked to the user', async () => {
      const dto = {
        line1: 'Flat 402, Sunshine Apts',
        line2: 'Home',
        city: 'Noida',
        state: 'Uttar Pradesh',
        zipCode: '201301',
      };
      jest.spyOn(prisma.address, 'create').mockResolvedValue({ id: 'a1', userId: 'u1', ...dto } as any);

      const res = await service.create('u1', dto as any);
      expect(prisma.address.create).toHaveBeenCalledWith({
        data: {
          userId: 'u1',
          ...dto,
        },
      });
      expect(res.id).toBe('a1');
    });
  });

  describe('findAll', () => {
    it('should return active non-archived addresses for the user', async () => {
      const mockList = [
        { id: 'a1', userId: 'u1', line1: 'Flat 402', line2: 'Home', city: 'Noida' },
        { id: 'a2', userId: 'u1', line1: 'Sector 18 Tower', line2: 'Work', city: 'Noida' },
      ];
      jest.spyOn(prisma.address, 'findMany').mockResolvedValue(mockList as any);

      const res = await service.findAll('u1');
      expect(prisma.address.findMany).toHaveBeenCalledWith({
        where: {
          userId: 'u1',
          OR: [
            { line2: null },
            { NOT: { line2: { startsWith: '[ARCHIVED]' } } },
          ],
        },
        orderBy: { createdAt: 'desc' },
      });
      expect(res).toEqual(mockList);
    });
  });

  describe('update', () => {
    it('should update in place when no bookings reference the address', async () => {
      const current = { id: 'a1', userId: 'u1', line1: 'Old Street', line2: 'Home', city: 'Noida' };
      jest.spyOn(prisma.address, 'findFirst').mockResolvedValue(current as any);
      jest.spyOn(prisma.booking, 'count').mockResolvedValue(0);
      jest.spyOn(prisma.address, 'update').mockResolvedValue({ ...current, line1: 'New Street' } as any);

      const res = await service.update('a1', 'u1', { line1: 'New Street' });
      expect(prisma.address.update).toHaveBeenCalledWith({
        where: { id: 'a1' },
        data: { line1: 'New Street' },
      });
      expect(res.line1).toBe('New Street');
    });

    it('should archive old address and create new record when bookings reference the address to preserve snapshot', async () => {
      const current = { id: 'a1', userId: 'u1', line1: 'Historic Street', line2: 'Home', city: 'Noida', state: 'UP', zipCode: '201301', latitude: 28.5, longitude: 77.3 };
      jest.spyOn(prisma.address, 'findFirst').mockResolvedValue(current as any);
      jest.spyOn(prisma.booking, 'count').mockResolvedValue(3); // 3 historic bookings
      jest.spyOn(prisma.address, 'update').mockResolvedValue({ ...current, line2: '[ARCHIVED] Home' } as any);
      jest.spyOn(prisma.address, 'create').mockResolvedValue({ ...current, id: 'a2_new', userId: 'u1', line1: 'Brand New Street' } as any);

      const res = await service.update('a1', 'u1', { line1: 'Brand New Street' });

      // Verified: old address was archived so historic bookings preserve their address
      expect(prisma.address.update).toHaveBeenCalledWith({
        where: { id: 'a1' },
        data: { line2: '[ARCHIVED] Home' },
      });
      // Verified: new address was created for future bookings
      expect(prisma.address.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          userId: 'u1',
          line1: 'Brand New Street',
          line2: 'Home',
        }),
      });
      expect(res.id).toBe('a2_new');
    });

    it('should not accumulate repeated [ARCHIVED] prefixes on update', async () => {
      const current = { id: 'a1', userId: 'u1', line1: 'Historic Street', line2: '[ARCHIVED] Home' };
      jest.spyOn(prisma.address, 'findFirst').mockResolvedValue(current as any);
      jest.spyOn(prisma.booking, 'count').mockResolvedValue(1);
      jest.spyOn(prisma.address, 'update').mockResolvedValue(current as any);
      jest.spyOn(prisma.address, 'create').mockResolvedValue({ id: 'a2', userId: 'u1' } as any);

      await service.update('a1', 'u1', { line1: 'Updated' });
      expect(prisma.address.update).toHaveBeenCalledWith({
        where: { id: 'a1' },
        data: { line2: '[ARCHIVED] Home' },
      });
    });

    it('should throw NotFoundException when updating an address belonging to another user', async () => {
      jest.spyOn(prisma.address, 'findFirst').mockResolvedValue(null);
      await expect(service.update('foreign_addr', 'u1', { line1: 'Hacked' }))
        .rejects.toThrow(NotFoundException);
    });
  });

  describe('remove', () => {
    it('should hard delete when no bookings reference the address', async () => {
      const current = { id: 'a1', userId: 'u1', line1: 'Street', line2: 'Home' };
      jest.spyOn(prisma.address, 'findFirst').mockResolvedValue(current as any);
      jest.spyOn(prisma.booking, 'count').mockResolvedValue(0);
      jest.spyOn(prisma.address, 'delete').mockResolvedValue(current as any);

      await service.remove('a1', 'u1');
      expect(prisma.address.delete).toHaveBeenCalledWith({ where: { id: 'a1' } });
    });

    it('should archive address when bookings reference it to prevent foreign key errors and preserve history', async () => {
      const current = { id: 'a1', userId: 'u1', line1: 'Street', line2: 'Home' };
      jest.spyOn(prisma.address, 'findFirst').mockResolvedValue(current as any);
      jest.spyOn(prisma.booking, 'count').mockResolvedValue(2); // 2 bookings
      jest.spyOn(prisma.address, 'update').mockResolvedValue({ ...current, line2: '[ARCHIVED] Home' } as any);

      await service.remove('a1', 'u1');
      expect(prisma.address.delete).not.toHaveBeenCalled();
      expect(prisma.address.update).toHaveBeenCalledWith({
        where: { id: 'a1' },
        data: { line2: '[ARCHIVED] Home' },
      });
    });

    it('should not accumulate repeated [ARCHIVED] prefixes on remove', async () => {
      const current = { id: 'a1', userId: 'u1', line1: 'Street', line2: '[ARCHIVED] Work' };
      jest.spyOn(prisma.address, 'findFirst').mockResolvedValue(current as any);
      jest.spyOn(prisma.booking, 'count').mockResolvedValue(1);
      jest.spyOn(prisma.address, 'update').mockResolvedValue(current as any);

      await service.remove('a1', 'u1');
      expect(prisma.address.update).toHaveBeenCalledWith({
        where: { id: 'a1' },
        data: { line2: '[ARCHIVED] Work' },
      });
    });

    it('should throw NotFoundException when removing an address belonging to another user', async () => {
      jest.spyOn(prisma.address, 'findFirst').mockResolvedValue(null);
      await expect(service.remove('foreign_addr', 'u1'))
        .rejects.toThrow(NotFoundException);
    });
  });
});
