import { Injectable, Logger } from '@nestjs/common';
import { IOtpProvider, OtpSendResult } from '../otp.interface';

@Injectable()
export class Msg91OtpProvider implements IOtpProvider {
  readonly name = 'MSG91';
  private readonly logger = new Logger(Msg91OtpProvider.name);
  private readonly authKey = process.env.MSG91_AUTH_KEY;
  private readonly templateId = process.env.MSG91_TEMPLATE_ID;

  async sendOtp(phone: string, otp: string): Promise<OtpSendResult> {
    if (!this.authKey || !this.templateId) {
      this.logger.error('MSG91_AUTH_KEY or MSG91_TEMPLATE_ID is not configured');
      return { success: false, error: 'MSG91 service configuration missing' };
    }

    try {
      const cleanedPhone = phone.replace(/\D/g, '').slice(-10);
      const url = `https://control.msg91.com/api/v5/otp?template_id=${this.templateId}&mobile=91${cleanedPhone}&otp=${otp}`;

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          authkey: this.authKey,
          'Content-Type': 'application/json',
        },
      });

      const data: any = await response.json();
      if (response.ok && data?.type === 'success') {
        return { success: true, messageId: data.message };
      }

      this.logger.error(`MSG91 error: ${JSON.stringify(data)}`);
      return { success: false, error: data?.message || 'Failed to dispatch OTP via MSG91' };
    } catch (err: any) {
      this.logger.error(`MSG91 network failure: ${err?.message || err}`);
      return { success: false, error: 'MSG91 gateway unreachable' };
    }
  }
}
