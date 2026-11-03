import {
  Injectable,
  Logger,
  BadRequestException,
  InternalServerErrorException,
} from '@nestjs/common';
import * as crypto from 'crypto';
import { IOtpProvider } from './otp.interface';
import { Fast2SmsOtpProvider } from './providers/fast2sms.provider';
import { Msg91OtpProvider } from './providers/msg91.provider';
import { DevMockOtpProvider } from './providers/dev-mock.provider';

interface StoredOtpSession {
  hashedCode: string;
  expiresAt: number;
  attempts: number;
}

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly sessions = new Map<string, StoredOtpSession>();
  private readonly activeProvider: IOtpProvider;

  constructor(
    private readonly fast2SmsProvider: Fast2SmsOtpProvider,
    private readonly msg91Provider: Msg91OtpProvider,
    private readonly devMockProvider: DevMockOtpProvider,
  ) {
    if (process.env.FAST2SMS_API_KEY) {
      this.activeProvider = this.fast2SmsProvider;
      this.logger.log('Active OTP Provider: FAST2SMS');
    } else if (process.env.MSG91_AUTH_KEY) {
      this.activeProvider = this.msg91Provider;
      this.logger.log('Active OTP Provider: MSG91');
    } else if (process.env.NODE_ENV !== 'production') {
      this.activeProvider = this.devMockProvider;
      this.logger.log('Active OTP Provider: DEV_MOCK (Development / Test only)');
    } else {
      this.activeProvider = {
        name: 'UNCONFIGURED',
        sendOtp: async () => ({
          success: false,
          error: 'Production SMS provider is not configured.',
        }),
      };
      this.logger.warn('No SMS provider configured in production environment.');
    }
  }

  private normalizePhone(phone: string): string {
    const cleaned = phone.replace(/\D/g, '').slice(-10);
    if (cleaned.length !== 10) {
      throw new BadRequestException('Please provide a valid 10-digit Indian mobile number');
    }
    return cleaned;
  }

  private hashOtp(otp: string): string {
    return crypto.createHash('sha256').update(otp).digest('hex');
  }

  async sendOtp(phone: string): Promise<{ success: boolean; message: string; devOtp?: string }> {
    const normalized = this.normalizePhone(phone);

    // Rate-limiting check: if an active non-expired OTP was requested in the last 60 seconds
    const existing = this.sessions.get(normalized);
    if (existing && existing.expiresAt - Date.now() > 4 * 60 * 1000) {
      throw new BadRequestException('Please wait 60 seconds before requesting another OTP');
    }

    // Generate 6-digit numeric OTP
    const isDev = process.env.NODE_ENV !== 'production' && this.activeProvider.name === 'DEV_MOCK';
    const otp = isDev ? '123456' : Math.floor(100000 + Math.random() * 900000).toString();

    const result = await this.activeProvider.sendOtp(normalized, otp);
    if (!result.success) {
      throw new InternalServerErrorException(
        result.error || 'Failed to dispatch verification code via SMS provider',
      );
    }

    // Store in-memory with 5-minute expiry
    this.sessions.set(normalized, {
      hashedCode: this.hashOtp(otp),
      expiresAt: Date.now() + 5 * 60 * 1000,
      attempts: 0,
    });

    return {
      success: true,
      message: 'Verification code sent successfully',
      ...(isDev ? { devOtp: otp } : {}),
    };
  }

  async verifyOtp(phone: string, code: string): Promise<boolean> {
    const normalized = this.normalizePhone(phone);
    const session = this.sessions.get(normalized);

    if (!session) {
      throw new BadRequestException('No verification code requested for this number or code expired');
    }

    if (Date.now() > session.expiresAt) {
      this.sessions.delete(normalized);
      throw new BadRequestException('Verification code has expired. Please request a new one');
    }

    if (session.attempts >= 3) {
      this.sessions.delete(normalized);
      throw new BadRequestException('Too many incorrect attempts. Please request a new code');
    }

    session.attempts += 1;
    const incomingHash = this.hashOtp(code.trim());

    if (incomingHash !== session.hashedCode) {
      throw new BadRequestException('Incorrect verification code. Please check and try again');
    }

    // Verified successfully -> clear session
    this.sessions.delete(normalized);
    return true;
  }
}
