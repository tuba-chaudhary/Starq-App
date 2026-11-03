export interface OtpSendResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

export interface IOtpProvider {
  readonly name: string;
  sendOtp(phone: string, otp: string): Promise<OtpSendResult>;
  verifyOtp?(phone: string, otp: string): Promise<boolean>;
}
