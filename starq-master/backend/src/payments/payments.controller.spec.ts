import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';

describe('PaymentsController', () => {
  let controller: PaymentsController;
  let paymentsService: jest.Mocked<Partial<PaymentsService>>;

  beforeEach(async () => {
    paymentsService = {
      verifySignature: jest.fn(),
      handleWebhook: jest.fn(),
      verifyPayment: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [PaymentsController],
      providers: [
        {
          provide: PaymentsService,
          useValue: paymentsService,
        },
      ],
    }).compile();

    controller = module.get<PaymentsController>(PaymentsController);
  });

  describe('webhook', () => {
    const rawPayloadString = JSON.stringify({
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: 'pay_123',
            order_id: 'order_123',
            amount: 49900,
            status: 'captured',
          },
        },
      },
    });
    const validRawBuffer = Buffer.from(rawPayloadString, 'utf8');

    it('should throw BadRequestException if x-razorpay-signature header is missing (undefined)', async () => {
      const mockReq = {
        rawBody: validRawBuffer,
        body: JSON.parse(rawPayloadString),
      } as any;

      await expect(controller.webhook(mockReq, undefined)).rejects.toThrow(
        new BadRequestException('Missing x-razorpay-signature header'),
      );
      expect(paymentsService.verifySignature).not.toHaveBeenCalled();
      expect(paymentsService.handleWebhook).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException if x-razorpay-signature header is empty string', async () => {
      const mockReq = {
        rawBody: validRawBuffer,
        body: JSON.parse(rawPayloadString),
      } as any;

      await expect(controller.webhook(mockReq, '')).rejects.toThrow(
        new BadRequestException('Missing x-razorpay-signature header'),
      );
      expect(paymentsService.verifySignature).not.toHaveBeenCalled();
      expect(paymentsService.handleWebhook).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException if x-razorpay-signature header is whitespace-only', async () => {
      const mockReq = {
        rawBody: validRawBuffer,
        body: JSON.parse(rawPayloadString),
      } as any;

      await expect(controller.webhook(mockReq, '   ')).rejects.toThrow(
        new BadRequestException('Missing x-razorpay-signature header'),
      );
      expect(paymentsService.verifySignature).not.toHaveBeenCalled();
      expect(paymentsService.handleWebhook).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException if rawBody is unavailable (undefined)', async () => {
      const mockReq = {
        rawBody: undefined,
        body: JSON.parse(rawPayloadString),
      } as any;

      await expect(
        controller.webhook(mockReq, 'valid_signature_123'),
      ).rejects.toThrow(
        new BadRequestException(
          'Raw request body is unavailable for signature verification',
        ),
      );
      expect(paymentsService.verifySignature).not.toHaveBeenCalled();
      expect(paymentsService.handleWebhook).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException if rawBody is an empty Buffer', async () => {
      const mockReq = {
        rawBody: Buffer.from(''),
        body: {},
      } as any;

      await expect(
        controller.webhook(mockReq, 'valid_signature_123'),
      ).rejects.toThrow(
        new BadRequestException(
          'Raw request body is unavailable for signature verification',
        ),
      );
      expect(paymentsService.verifySignature).not.toHaveBeenCalled();
      expect(paymentsService.handleWebhook).not.toHaveBeenCalled();
    });

    it('should throw BadRequestException if verifySignature returns false (invalid signature)', async () => {
      const mockReq = {
        rawBody: validRawBuffer,
        body: JSON.parse(rawPayloadString),
      } as any;

      (paymentsService.verifySignature as jest.Mock).mockReturnValue(false);

      await expect(
        controller.webhook(mockReq, 'invalid_signature_456'),
      ).rejects.toThrow(new BadRequestException('Invalid signature'));

      expect(paymentsService.verifySignature).toHaveBeenCalledWith(
        validRawBuffer,
        'invalid_signature_456',
      );
      expect(paymentsService.handleWebhook).not.toHaveBeenCalled();
    });

    it('should process webhook and return handleWebhook result for valid signature and raw body', async () => {
      const parsedBody = JSON.parse(rawPayloadString);
      const mockReq = {
        rawBody: validRawBuffer,
        body: parsedBody,
      } as any;

      (paymentsService.verifySignature as jest.Mock).mockReturnValue(true);
      (paymentsService.handleWebhook as jest.Mock).mockResolvedValue({
        status: 'success',
      });

      const result = await controller.webhook(mockReq, 'valid_signature_789');

      expect(paymentsService.verifySignature).toHaveBeenCalledWith(
        validRawBuffer,
        'valid_signature_789',
      );
      expect(paymentsService.handleWebhook).toHaveBeenCalledWith(parsedBody);
      expect(result).toEqual({ status: 'success' });
    });

    it('should parse payload from rawBody if req.body is not pre-parsed', async () => {
      const mockReq = {
        rawBody: validRawBuffer,
        body: undefined, // not yet parsed by body-parser
      } as any;

      (paymentsService.verifySignature as jest.Mock).mockReturnValue(true);
      (paymentsService.handleWebhook as jest.Mock).mockResolvedValue({
        status: 'success',
      });

      const result = await controller.webhook(mockReq, 'valid_signature_789');

      expect(paymentsService.verifySignature).toHaveBeenCalledWith(
        validRawBuffer,
        'valid_signature_789',
      );
      expect(paymentsService.handleWebhook).toHaveBeenCalledWith(
        JSON.parse(rawPayloadString),
      );
      expect(result).toEqual({ status: 'success' });
    });
  });

  describe('verify', () => {
    it('should return { success: true } when verifyPayment succeeds', async () => {
      (paymentsService.verifyPayment as jest.Mock).mockResolvedValue(true);

      const result = await controller.verify({
        razorpay_order_id: 'order_1',
        razorpay_payment_id: 'pay_1',
        razorpay_signature: 'sig_1',
      });

      expect(result).toEqual({ success: true });
      expect(paymentsService.verifyPayment).toHaveBeenCalledWith(
        'order_1',
        'pay_1',
        'sig_1',
      );
    });

    it('should throw BadRequestException when verifyPayment fails', async () => {
      (paymentsService.verifyPayment as jest.Mock).mockResolvedValue(false);

      await expect(
        controller.verify({
          razorpay_order_id: 'order_1',
          razorpay_payment_id: 'pay_1',
          razorpay_signature: 'sig_bad',
        }),
      ).rejects.toThrow(new BadRequestException('Payment verification failed'));
    });
  });
});
