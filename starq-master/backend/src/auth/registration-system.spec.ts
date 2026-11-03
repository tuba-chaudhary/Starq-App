import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { OtpService } from './otp/otp.service';
import { Fast2SmsOtpProvider } from './otp/providers/fast2sms.provider';
import { Msg91OtpProvider } from './otp/providers/msg91.provider';
import { DevMockOtpProvider } from './otp/providers/dev-mock.provider';
import { PartnersService } from '../partners/partners.service';
import { AdminService } from '../admin/admin.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrivateStorageService } from '../storage/private-storage.service';
import { RewardsService } from '../rewards/rewards.service';
import { RolesGuard } from './roles.guard';
import { Reflector } from '@nestjs/core';
import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';

describe('STARQ Registration & Verification System', () => {
  let authService: AuthService;
  let otpService: OtpService;
  let partnersService: PartnersService;
  let adminService: AdminService;
  let rolesGuard: RolesGuard;
  let reflector: Reflector;

  const mockPrisma = {
    user: {
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    partnerApplication: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    partner: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
    $transaction: jest.fn(async (ops) => {
      if (Array.isArray(ops)) return ops;
      if (typeof ops === 'function') return ops(mockPrisma);
      return [];
    }),
  };

  const mockJwt = {
    sign: jest.fn().mockReturnValue('mock_jwt_token'),
  };

  const mockNotifications = {
    sendNotification: jest.fn().mockResolvedValue(true),
  };

  const mockStorage = {
    savePrivateFile: jest.fn().mockResolvedValue({
      storedFilename: '123_test.jpg',
      originalName: 'test.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 1024,
      filePath: '/storage/test.jpg',
    }),
    getPrivateFilePath: jest.fn().mockReturnValue('/storage/test.jpg'),
    deletePrivateFile: jest.fn().mockResolvedValue(undefined),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        OtpService,
        Fast2SmsOtpProvider,
        Msg91OtpProvider,
        DevMockOtpProvider,
        PartnersService,
        AdminService,
        RolesGuard,
        Reflector,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JwtService, useValue: mockJwt },
        { provide: NotificationsService, useValue: mockNotifications },
        { provide: PrivateStorageService, useValue: mockStorage },
        { provide: RewardsService, useValue: {} },
      ],
    }).compile();

    authService = module.get<AuthService>(AuthService);
    otpService = module.get<OtpService>(OtpService);
    partnersService = module.get<PartnersService>(PartnersService);
    adminService = module.get<AdminService>(AdminService);
    rolesGuard = module.get<RolesGuard>(RolesGuard);
    reflector = module.get<Reflector>(Reflector);
  });

  describe('1. OTP Architecture (Provider-Independent)', () => {
    it('sends OTP in test/development using DevMockOtpProvider', async () => {
      const result = await otpService.sendOtp('9876543210');
      expect(result.success).toBe(true);
      expect(result.devOtp).toBe('123456');
    });

    it('rejects invalid mobile number format', async () => {
      await expect(otpService.sendOtp('123')).rejects.toThrow(BadRequestException);
    });

    it('verifies correct OTP code', async () => {
      await otpService.sendOtp('9876543210');
      const isValid = await otpService.verifyOtp('9876543210', '123456');
      expect(isValid).toBe(true);
    });

    it('rejects incorrect OTP code', async () => {
      await otpService.sendOtp('9876543210');
      await expect(otpService.verifyOtp('9876543210', '000000')).rejects.toThrow(BadRequestException);
    });
  });

  describe('2. Shared Account & Customer Registration', () => {
    it('logs in existing customer via OTP without creating duplicate User', async () => {
      const existingUser = {
        id: 'u1',
        phone: '9876543210',
        email: 'customer@test.com',
        fullName: 'Test Customer',
        role: 'CUSTOMER',
        roles: ['CUSTOMER'],
        referralCode: 'STARQ999',
      };
      await otpService.sendOtp('9876543210');

      mockPrisma.user.findFirst.mockResolvedValue(existingUser);

      const result = await authService.verifyOtp({ phone: '9876543210', otp: '123456' });
      expect(result.accessToken).toBe('mock_jwt_token');
      expect(result.user.id).toBe('u1');
      expect(mockPrisma.user.create).not.toHaveBeenCalled();
    });

    it('registers new customer via OTP when mobile does not exist', async () => {
      await otpService.sendOtp('9876543210');

      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.user.create.mockResolvedValue({
        id: 'u2',
        phone: '9876543210',
        email: '9876543210@phone.starq.app',
        fullName: 'New Customer',
        role: 'CUSTOMER',
        roles: ['CUSTOMER'],
        referralCode: 'STARQ111',
      });

      const result = await authService.verifyOtp({
        phone: '9876543210',
        otp: '123456',
        fullName: 'New Customer',
      });

      expect(result.user.id).toBe('u2');
      expect(mockPrisma.user.create).toHaveBeenCalled();
    });
  });

  describe('3. Service Partner Application Flow', () => {
    it('creates partner application with private document storage', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1', phone: '9876543210' });
      mockPrisma.partnerApplication.findUnique.mockResolvedValue(null);
      mockPrisma.partnerApplication.create.mockResolvedValue({
        id: 'app1',
        applicationId: 'STQ-APP-88888',
        userId: 'u1',
        status: 'PENDING_VERIFICATION',
      });

      const result = await partnersService.applyPartner(
        'u1',
        {
          fullName: 'Partner Candidate',
          email: 'partner@test.com',
          address: 'Shop 12, Main St',
          city: 'Mumbai',
          pinCode: '400001',
          idDocumentType: 'AADHAAR' as any,
        },
        { buffer: Buffer.from('photo'), originalname: 'p.jpg', mimetype: 'image/jpeg' },
        { buffer: Buffer.from('id'), originalname: 'doc.pdf', mimetype: 'application/pdf' },
      );

      expect(mockStorage.savePrivateFile).toHaveBeenCalledTimes(2);
      expect(result.status).toBe('PENDING_VERIFICATION');
    });

    it('rejects partner application if profile photo is missing', async () => {
      await expect(
        partnersService.applyPartner(
          'u1',
          {
            fullName: 'Partner Candidate',
            email: 'partner@test.com',
            address: 'Shop 12',
            city: 'Mumbai',
            pinCode: '400001',
            idDocumentType: 'PAN' as any,
          },
          undefined,
          { buffer: Buffer.from('id'), originalname: 'doc.pdf', mimetype: 'application/pdf' },
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('allows resubmitting an application when previously rejected', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1', phone: '9876543210' });
      mockPrisma.partnerApplication.findUnique.mockResolvedValue({
        id: 'app1',
        applicationId: 'STQ-APP-88888',
        status: 'REJECTED',
        profilePhotoPath: 'old_photo.jpg',
        idDocumentPath: 'old_doc.pdf',
      });
      mockPrisma.partnerApplication.update.mockResolvedValue({
        id: 'app1',
        applicationId: 'STQ-APP-88888',
        status: 'PENDING_VERIFICATION',
        rejectionReason: null,
      });

      const res = await partnersService.applyPartner(
        'u1',
        {
          fullName: 'Partner Resubmitting',
          email: 'partner@test.com',
          address: 'Shop 12, Main St',
          city: 'Mumbai',
          pinCode: '400001',
          idDocumentType: 'AADHAAR' as any,
        },
        { buffer: Buffer.from('photo'), originalname: 'p.jpg', mimetype: 'image/jpeg' },
        { buffer: Buffer.from('id'), originalname: 'doc.pdf', mimetype: 'application/pdf' },
      );

      expect(mockPrisma.partnerApplication.update).toHaveBeenCalled();
      expect(res.status).toBe('PENDING_VERIFICATION');
    });
  });

  describe('4. Admin Verification & Partner Lifecycle', () => {
    it('prevents admins from approving their own application', async () => {
      mockPrisma.partnerApplication.findUnique.mockResolvedValue({
        id: 'app1',
        userId: 'admin_1',
      });

      await expect(adminService.approvePartnerApplication('app1', 'admin_1')).rejects.toThrow(
        BadRequestException,
      );
    });

    it('transactionally approves application and adds PARTNER role to user.roles', async () => {
      mockPrisma.partnerApplication.findUnique.mockResolvedValue({
        id: 'app1',
        userId: 'candidate_user',
        city: 'Mumbai',
        status: 'PENDING_VERIFICATION',
        user: { id: 'candidate_user', role: 'CUSTOMER', roles: ['CUSTOMER'] },
      });
      mockPrisma.partnerApplication.update.mockReturnValue({ id: 'app1', status: 'APPROVED' });
      mockPrisma.user.update.mockReturnValue({ id: 'candidate_user', role: 'PARTNER' });
      mockPrisma.partner.upsert.mockReturnValue({ id: 'p1', isActive: true });

      const approved = await adminService.approvePartnerApplication('app1', 'admin_different');
      expect(mockPrisma.$transaction).toHaveBeenCalled();
      expect(mockNotifications.sendNotification).toHaveBeenCalledWith(
        'candidate_user',
        expect.stringContaining('Approved'),
        expect.any(String),
        'PARTNER_APPROVED',
      );
    });

    it('requires a mandatory rejection reason when rejecting', async () => {
      await expect(
        adminService.rejectPartnerApplication('app1', 'admin_1', ''),
      ).rejects.toThrow(BadRequestException);
    });

    it('rejects partner application and stores reason', async () => {
      mockPrisma.partnerApplication.findUnique.mockResolvedValue({
        id: 'app1',
        userId: 'u1',
      });
      mockPrisma.partnerApplication.update.mockResolvedValue({
        id: 'app1',
        status: 'REJECTED',
        rejectionReason: 'ID proof unreadable',
      });

      const rejected = await adminService.rejectPartnerApplication(
        'app1',
        'admin_1',
        'ID proof unreadable',
      );
      expect(rejected.status).toBe('REJECTED');
    });

    it('suspends partner and deactivates partner operational status', async () => {
      mockPrisma.partnerApplication.findUnique.mockResolvedValue({
        id: 'app1',
        userId: 'p_user',
        user: { id: 'p_user' },
      });

      await adminService.suspendPartner('app1', 'admin_1');
      expect(mockPrisma.$transaction).toHaveBeenCalled();
    });
  });

  describe('5. Mode Switching & Role Access Guarding', () => {
    it('blocks switching to partner mode if partner application is not approved', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        roles: ['CUSTOMER'],
        partnerApplication: { status: 'PENDING_VERIFICATION' },
        partnerProfile: null,
      });

      await expect(authService.switchMode('u1', 'PARTNER')).rejects.toThrow(ForbiddenException);
    });

    it('allows switching to partner mode when user has approved partner role', async () => {
      mockPrisma.user.findUnique.mockResolvedValue({
        id: 'u1',
        roles: ['CUSTOMER', 'PARTNER'],
        partnerApplication: { status: 'APPROVED' },
        partnerProfile: { isActive: true },
      });
      mockPrisma.user.update.mockResolvedValue({
        id: 'u1',
        role: 'PARTNER',
        roles: ['CUSTOMER', 'PARTNER'],
        email: 'test@starq.com',
      });

      const res = await authService.switchMode('u1', 'PARTNER');
      expect(res.user.role).toBe('PARTNER');
      expect(res.user.roles).toContain('PARTNER');
    });

    it('RolesGuard allows access if required role is present in user.roles', () => {
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['PARTNER']);
      const mockContext = {
        getHandler: () => {},
        getClass: () => {},
        switchToHttp: () => ({
          getRequest: () => ({ user: { role: 'CUSTOMER', roles: ['CUSTOMER', 'PARTNER'] } }),
        }),
      } as any;

      expect(rolesGuard.canActivate(mockContext)).toBe(true);
    });

    it('RolesGuard blocks access if user only has CUSTOMER role', () => {
      jest.spyOn(reflector, 'getAllAndOverride').mockReturnValue(['PARTNER']);
      const mockContext = {
        getHandler: () => {},
        getClass: () => {},
        switchToHttp: () => ({
          getRequest: () => ({ user: { role: 'CUSTOMER', roles: ['CUSTOMER'] } }),
        }),
      } as any;

      expect(rolesGuard.canActivate(mockContext)).toBe(false);
    });
  });
});
