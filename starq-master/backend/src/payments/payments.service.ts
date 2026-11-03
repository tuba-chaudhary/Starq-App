import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AssignmentsService } from '../assignments/assignments.service';
import { NotificationsService } from '../notifications/notifications.service';
import { RewardsService } from '../rewards/rewards.service';
import * as crypto from 'crypto';

@Injectable()
export class PaymentsService {
  constructor(
    private prisma: PrismaService,
    private assignments: AssignmentsService,
    private notificationsService: NotificationsService,
    private rewardsService: RewardsService,
  ) {}

  verifySignature(body: string | Buffer, signature: string): boolean {
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
    if (!secret) {
      // Enforce secret presence for production safety
      throw new BadRequestException('Webhook secret is not configured.');
    }

    if (!signature) {
      return false;
    }

    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(body)
      .digest('hex');

    const expectedBuffer = Buffer.from(expectedSignature, 'utf8');
    const signatureBuffer = Buffer.from(signature, 'utf8');

    if (expectedBuffer.length !== signatureBuffer.length) {
      return false;
    }

    return crypto.timingSafeEqual(expectedBuffer, signatureBuffer);
  }

  async handleWebhook(event: any) {
    const eventName = event.event;
    
    if (eventName === 'payment.captured') {
      const paymentEntity = event.payload.payment.entity;
      const orderId = paymentEntity.order_id;
      const paymentId = paymentEntity.id;

      // Find the payment record
      const payment = await this.prisma.payment.findFirst({
        where: { providerOrderId: orderId }
      });

      if (!payment) {
        console.warn('Payment record not found for order:', orderId);
        return { status: 'ignored' };
      }

      // Idempotency check
      if (payment.status === 'captured') {
        return { status: 'already_processed' };
      }

      // Update payment
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: 'captured',
          providerPaymentId: paymentId,
        }
      });

      // Update booking to CONFIRMED
      await this.prisma.booking.update({
        where: { id: payment.bookingId },
        data: { status: 'CONFIRMED' }
      });
      await this.prisma.bookingStatusHistory.create({
        data: { bookingId: payment.bookingId, status: 'CONFIRMED' }
      });
      
      const booking = await this.prisma.booking.findUnique({ where: { id: payment.bookingId } });
      if (booking) {
        await this.notificationsService.sendNotification(
          booking.userId,
          'Payment Successful',
          'Your booking is confirmed.',
          'CONFIRMED',
          booking.id
        );
      }

      // Attempt auto assignment
      this.assignments.autoAssign(payment.bookingId);

      // Trigger referral reward check (handles case where booking is already COMPLETED)
      try {
        await this.rewardsService.awardReferralRewardIfEligible(payment.bookingId);
      } catch (err: any) {
        console.warn('Referral reward check error on webhook capture:', err?.message || err);
      }

      return { status: 'success' };
    }
    
    if (eventName === 'payment.failed') {
      const paymentEntity = event.payload.payment.entity;
      const orderId = paymentEntity.order_id;

      const payment = await this.prisma.payment.findFirst({
        where: { providerOrderId: orderId }
      });

      if (payment && payment.status !== 'failed') {
        await this.prisma.payment.update({
          where: { id: payment.id },
          data: { status: 'failed' }
        });
        
        await this.prisma.booking.update({
          where: { id: payment.bookingId },
          data: { status: 'PAYMENT_FAILED' }
        });
      }
    }

    return { status: 'ignored' };
  }

  async verifyPayment(orderId: string, paymentId: string, signature: string) {
    if (orderId && orderId.startsWith('order_mock_')) {
      const payment = await this.prisma.payment.findFirst({
        where: { providerOrderId: orderId }
      });
      if (payment && payment.status !== 'captured') {
        await this.prisma.payment.update({
          where: { id: payment.id },
          data: { status: 'captured', providerPaymentId: paymentId || ('pay_mock_' + Date.now()) }
        });
        await this.prisma.booking.update({
          where: { id: payment.bookingId },
          data: { status: 'CONFIRMED' }
        });
        await this.prisma.bookingStatusHistory.create({
          data: { bookingId: payment.bookingId, status: 'CONFIRMED' }
        });
        this.assignments.autoAssign(payment.bookingId);

        // Trigger referral reward check
        try {
          await this.rewardsService.awardReferralRewardIfEligible(payment.bookingId);
        } catch (err: any) {
          console.warn('Referral reward check error on mock payment verify:', err?.message || err);
        }
      }
      return true;
    }

    const secret = process.env.RAZORPAY_KEY_SECRET;
    if (!secret) return false;

    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(orderId + '|' + paymentId)
      .digest('hex');

    if (expectedSignature !== signature) {
      return false;
    }

    const payment = await this.prisma.payment.findFirst({
      where: { providerOrderId: orderId }
    });

    if (payment && payment.status !== 'captured') {
      await this.prisma.payment.update({
        where: { id: payment.id },
        data: { status: 'captured', providerPaymentId: paymentId }
      });
      await this.prisma.booking.update({
        where: { id: payment.bookingId },
        data: { status: 'CONFIRMED' }
      });
      await this.prisma.bookingStatusHistory.create({
        data: { bookingId: payment.bookingId, status: 'CONFIRMED' }
      });
      
      const booking = await this.prisma.booking.findUnique({ where: { id: payment.bookingId } });
      if (booking) {
        await this.notificationsService.sendNotification(
          booking.userId,
          'Payment Successful',
          'Your booking is confirmed.',
          'CONFIRMED',
          booking.id
        );
      }

      // Attempt auto assignment
      this.assignments.autoAssign(payment.bookingId);

      // Trigger referral reward check
      try {
        await this.rewardsService.awardReferralRewardIfEligible(payment.bookingId);
      } catch (err: any) {
        console.warn('Referral reward check error on live payment verify:', err?.message || err);
      }
    }

    return true;
  }
}
