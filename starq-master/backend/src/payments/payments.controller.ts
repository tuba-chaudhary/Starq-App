import {
  Controller,
  Post,
  Headers,
  Req,
  BadRequestException,
  Body,
  RawBodyRequest,
} from '@nestjs/common';
import { Request } from 'express';
import { PaymentsService } from './payments.service';

@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('webhook')
  async webhook(
    @Req() req: RawBodyRequest<Request>,
    @Headers('x-razorpay-signature') signature?: string,
  ) {
    if (!signature || signature.trim() === '') {
      throw new BadRequestException('Missing x-razorpay-signature header');
    }

    const rawBody = req.rawBody;
    if (!rawBody || (Buffer.isBuffer(rawBody) && rawBody.length === 0)) {
      throw new BadRequestException(
        'Raw request body is unavailable for signature verification',
      );
    }

    if (!this.paymentsService.verifySignature(rawBody, signature)) {
      throw new BadRequestException('Invalid signature');
    }

    let payload = req.body;
    if (!payload || typeof payload !== 'object') {
      try {
        payload = JSON.parse(rawBody.toString('utf8'));
      } catch {
        throw new BadRequestException('Invalid webhook JSON payload');
      }
    }

    return this.paymentsService.handleWebhook(payload);
  }

  @Post('verify')
  async verify(@Body() body: { razorpay_order_id: string; razorpay_payment_id: string; razorpay_signature: string }) {
    const isValid = await this.paymentsService.verifyPayment(
      body.razorpay_order_id,
      body.razorpay_payment_id,
      body.razorpay_signature,
    );
    if (!isValid) throw new BadRequestException('Payment verification failed');
    return { success: true };
  }
}
