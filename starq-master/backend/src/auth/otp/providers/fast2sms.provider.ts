import { Injectable, Logger } from '@nestjs/common';
import { IOtpProvider, OtpSendResult } from '../otp.interface';

@Injectable()
export class Fast2SmsOtpProvider implements IOtpProvider {
  readonly name = 'FAST2SMS';
  private readonly logger = new Logger(Fast2SmsOtpProvider.name);
  private readonly apiKey = process.env.FAST2SMS_API_KEY;

  async sendOtp(phone: string, otp: string): Promise<OtpSendResult> {
    if (!this.apiKey) {
      this.logger.error('FAST2SMS_API_KEY is not configured');
      return { success: false, error: 'SMS service configuration missing' };
    }

    try {
      // Clean phone number to 10 digits
      const cleanedPhone = phone.replace(/\D/g, '').slice(-10);
      const url = 'https://www.fast2sms.com/dev/bulkV2';

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          authorization: this.apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          variables_values: otp,
          route: 'otp',
          numbers: cleanedPhone,
        }),
      });

      const data: any = await response.json();
      if (response.ok && data?.return === true) {
        return { success: true, messageId: data.request_id };
      }

      this.logger.error(`Fast2SMS error: ${JSON.stringify(data)}`);
      return { success: false, error: data?.message || 'Failed to dispatch SMS' };
    } catch (err: any) {
      this.logger.error(`Fast2SMS network failure: ${err?.message || err}`);
      return { success: false, error: 'SMS gateway unreachable' };
    }
  }
}
