import { Injectable, Logger, ForbiddenException } from '@nestjs/common';
import { IOtpProvider, OtpSendResult } from '../otp.interface';

@Injectable()
export class DevMockOtpProvider implements IOtpProvider {
  readonly name = 'DEV_MOCK';
  private readonly logger = new Logger(DevMockOtpProvider.name);

  async sendOtp(phone: string, otp: string): Promise<OtpSendResult> {
    if (process.env.NODE_ENV === 'production') {
      this.logger.error('CRITICAL: DevMockOtpProvider attempted in production environment!');
      throw new ForbiddenException('Mock OTP is strictly prohibited in production.');
    }

    this.logger.log(`[DEV ONLY] Dispatched OTP ${otp} to phone ${phone}`);
    return { success: true, messageId: `mock_${Date.now()}` };
  }
}
