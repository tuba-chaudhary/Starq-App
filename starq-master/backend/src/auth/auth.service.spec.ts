import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';
import {
  ConflictException,
  UnauthorizedException,
  BadRequestException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

describe('AuthService', () => {
  let service: AuthService;
  let prisma: PrismaService;
  let jwt: JwtService;

  const mockPrisma = {
    user: {
      findFirst: jest.fn(),
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    referral: {
      create: jest.fn(),
    },
    deviceToken: {
      deleteMany: jest.fn(),
    },
    $transaction: jest.fn(async (cb) => {
      if (typeof cb === 'function') {
        return cb(mockPrisma);
      }
      return Promise.all(cb);
    }),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
        {
          provide: JwtService,
          useValue: {
            sign: jest.fn(() => 'mockJwtToken'),
          },
        },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    prisma = module.get<PrismaService>(PrismaService);
    jwt = module.get<JwtService>(JwtService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('register', () => {
    it('should successfully register a new user without a referral code', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.user.create.mockResolvedValue({
        id: 'new-user-1',
        email: 'test@test.com',
        password: 'hashed',
        role: 'CUSTOMER',
        fullName: 'Test User',
        phone: '9876543210',
      });

      const result = await service.register({
        email: 'test@test.com',
        password: 'password123',
        fullName: 'Test User',
        phone: '9876543210',
      });

      expect(result.accessToken).toBe('mockJwtToken');
      expect(result.user).toEqual({
        id: 'new-user-1',
        email: 'test@test.com',
        fullName: 'Test User',
        role: 'CUSTOMER',
        phone: '9876543210',
        referralCode: null,
      });
      expect(mockPrisma.referral.create).not.toHaveBeenCalled();
    });

    it('should successfully register with a valid referral code and create a PENDING referral record atomically', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'referrer-123',
        email: 'referrer@test.com',
        phone: '9111111111',
      });
      mockPrisma.user.create.mockResolvedValue({
        id: 'new-referee-456',
        email: 'referee@test.com',
        password: 'hashed',
        role: 'CUSTOMER',
        fullName: 'New Referee',
        phone: '9222222222',
      });
      mockPrisma.referral.create.mockResolvedValue({
        id: 'ref-row-1',
        referrerId: 'referrer-123',
        refereeId: 'new-referee-456',
        referralCode: 'STARQ123',
        status: 'PENDING',
      });

      const result = await service.register({
        email: 'referee@test.com',
        password: 'password123',
        fullName: 'New Referee',
        phone: '9222222222',
        referralCode: ' starq123 ',
      });

      expect(mockPrisma.user.findUnique).toHaveBeenCalledWith({
        where: { referralCode: 'STARQ123' },
        select: { id: true, email: true, phone: true },
      });
      expect(mockPrisma.referral.create).toHaveBeenCalledWith({
        data: {
          referrerId: 'referrer-123',
          refereeId: 'new-referee-456',
          referralCode: 'STARQ123',
          status: 'PENDING',
        },
      });
      expect(result.accessToken).toBe('mockJwtToken');
      expect(result.user.id).toBe('new-referee-456');
    });

    it('should reject malformed referral code with BadRequestException', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);

      await expect(
        service.register({
          email: 'new@test.com',
          password: 'password123',
          fullName: 'New User',
          referralCode: 'INVALIDCODE',
        }),
      ).rejects.toThrow(BadRequestException);

      expect(mockPrisma.user.findUnique).not.toHaveBeenCalled();
      expect(mockPrisma.user.create).not.toHaveBeenCalled();
    });

    it('should reject non-existent / unknown referral code with BadRequestException', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.user.findUnique.mockResolvedValue(null); // No referrer found

      await expect(
        service.register({
          email: 'new@test.com',
          password: 'password123',
          fullName: 'New User',
          referralCode: 'STARQ999',
        }),
      ).rejects.toThrow(BadRequestException);

      expect(mockPrisma.user.create).not.toHaveBeenCalled();
    });

    it('should reject self-referral by same email with BadRequestException', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user-1',
        email: 'same@test.com',
        phone: '9111111111',
      });

      await expect(
        service.register({
          email: 'same@test.com',
          password: 'password123',
          fullName: 'Self Referrer',
          referralCode: 'STARQ123',
        }),
      ).rejects.toThrow(BadRequestException);

      expect(mockPrisma.user.create).not.toHaveBeenCalled();
    });

    it('should reject self-referral by same phone number with BadRequestException', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'user-1',
        email: 'other@test.com',
        phone: '9999999999',
      });

      await expect(
        service.register({
          email: 'different@test.com',
          phone: '9999999999',
          password: 'password123',
          fullName: 'Self Referrer',
          referralCode: 'STARQ123',
        }),
      ).rejects.toThrow(BadRequestException);

      expect(mockPrisma.user.create).not.toHaveBeenCalled();
    });

    it('should throw ConflictException on duplicate email/phone during initial check', async () => {
      mockPrisma.user.findFirst.mockResolvedValue({
        id: '1',
        email: 'test@test.com',
      });

      await expect(
        service.register({
          email: 'test@test.com',
          password: 'pass',
          fullName: 'Test',
        }),
      ).rejects.toThrow(ConflictException);

      expect(mockPrisma.$transaction).not.toHaveBeenCalled();
    });

    it('should roll back and throw ConflictException if duplicate referral attempt violates refereeId constraint', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'referrer-1',
        email: 'ref@test.com',
        phone: null,
      });

      const p2002Error = new Prisma.PrismaClientKnownRequestError(
        'Unique constraint violation',
        {
          code: 'P2002',
          clientVersion: '5.22.0',
          meta: { target: ['refereeId'] },
        },
      );

      mockPrisma.user.create.mockResolvedValue({ id: 'u-1', email: 'a@b.com' });
      mockPrisma.referral.create.mockRejectedValue(p2002Error);

      await expect(
        service.register({
          email: 'a@b.com',
          password: 'pass',
          fullName: 'User',
          referralCode: 'STARQ123',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('should roll back transaction and bubble error if referral creation fails unexpectedly', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'referrer-1',
        email: 'ref@test.com',
        phone: null,
      });

      mockPrisma.user.create.mockResolvedValue({ id: 'u-1', email: 'a@b.com' });
      mockPrisma.referral.create.mockRejectedValue(new Error('Database disk error'));

      await expect(
        service.register({
          email: 'a@b.com',
          password: 'pass',
          fullName: 'User',
          referralCode: 'STARQ123',
        }),
      ).rejects.toThrow('Database disk error');
    });
  });

  describe('login', () => {
    it('should successfully login with valid credentials', async () => {
      const hashed = await bcrypt.hash('password123', 10);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: '1',
        email: 'test@test.com',
        password: hashed,
        role: 'CUSTOMER',
      });

      const result = await service.login({
        email: 'test@test.com',
        password: 'password123',
      });
      expect(result.accessToken).toBe('mockJwtToken');
    });

    it('should retain existing referral code across logins without regenerating', async () => {
      const hashed = await bcrypt.hash('password123', 10);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: '1',
        email: 'test@test.com',
        password: hashed,
        role: 'CUSTOMER',
        phone: '9876543210',
        referralCode: 'STARQPERM1',
      });

      const result1 = await service.login({
        email: 'test@test.com',
        password: 'password123',
      });
      expect(result1.user.referralCode).toBe('STARQPERM1');
      expect(mockPrisma.user.update).not.toHaveBeenCalled();

      const result2 = await service.login({
        email: 'test@test.com',
        password: 'password123',
      });
      expect(result2.user.referralCode).toBe('STARQPERM1');
      expect(result2.user.referralCode).toBe(result1.user.referralCode);
    });

    it('should backfill a stable referral code on login if user lacks one', async () => {
      const hashed = await bcrypt.hash('password123', 10);
      mockPrisma.user.findUnique.mockResolvedValue({
        id: '1',
        email: 'legacy@test.com',
        password: hashed,
        role: 'CUSTOMER',
        phone: '9876543210',
        referralCode: null,
      });
      mockPrisma.user.update.mockImplementation(async ({ data }) => ({
        id: '1',
        email: 'legacy@test.com',
        password: hashed,
        role: 'CUSTOMER',
        phone: '9876543210',
        referralCode: data.referralCode,
      }));

      const result = await service.login({
        email: 'legacy@test.com',
        password: 'password123',
      });

      expect(mockPrisma.user.update).toHaveBeenCalled();
      expect(result.user.referralCode).toMatch(/^STARQ[A-Z0-9]{3,8}$/);
    });
  });
});
