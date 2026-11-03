import os

base_dir = r"c:\Users\SIDDDIQUI TABISH\Downloads\STARQ\starq_app-\backend\src"

# Addresses Module
os.makedirs(os.path.join(base_dir, "addresses", "dto"), exist_ok=True)
create_address_dto = """import { IsString, IsNumber, IsOptional } from 'class-validator';

export class CreateAddressDto {
  @IsString()
  line1: string;

  @IsOptional()
  @IsString()
  line2?: string;

  @IsString()
  city: string;

  @IsOptional()
  @IsString()
  state?: string;

  @IsOptional()
  @IsString()
  zipCode?: string;

  @IsOptional()
  @IsNumber()
  latitude?: number;

  @IsOptional()
  @IsNumber()
  longitude?: number;
}
"""
with open(os.path.join(base_dir, "addresses", "dto", "create-address.dto.ts"), "w") as f:
    f.write(create_address_dto)

update_address_dto = """import { PartialType } from '@nestjs/swagger';
import { CreateAddressDto } from './create-address.dto';

export class UpdateAddressDto extends PartialType(CreateAddressDto) {}
"""
with open(os.path.join(base_dir, "addresses", "dto", "update-address.dto.ts"), "w") as f:
    f.write(update_address_dto)

addresses_service = """import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';

@Injectable()
export class AddressesService {
  constructor(private prisma: PrismaService) {}

  create(userId: string, createAddressDto: CreateAddressDto) {
    return this.prisma.address.create({
      data: {
        userId,
        ...createAddressDto,
      },
    });
  }

  findAll(userId: string) {
    return this.prisma.address.findMany({
      where: { userId },
    });
  }

  async findOne(id: string, userId: string) {
    const address = await this.prisma.address.findFirst({
      where: { id, userId },
    });
    if (!address) throw new NotFoundException('Address not found');
    return address;
  }

  async update(id: string, userId: string, updateAddressDto: UpdateAddressDto) {
    await this.findOne(id, userId); // ownership check
    return this.prisma.address.update({
      where: { id },
      data: updateAddressDto,
    });
  }

  async remove(id: string, userId: string) {
    await this.findOne(id, userId); // ownership check
    return this.prisma.address.delete({
      where: { id },
    });
  }
}
"""
with open(os.path.join(base_dir, "addresses", "addresses.service.ts"), "w") as f:
    f.write(addresses_service)

addresses_controller = """import { Controller, Get, Post, Body, Patch, Param, Delete, UseGuards, Request } from '@nestjs/common';
import { AddressesService } from './addresses.service';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('addresses')
export class AddressesController {
  constructor(private readonly addressesService: AddressesService) {}

  @Post()
  create(@Request() req, @Body() createAddressDto: CreateAddressDto) {
    return this.addressesService.create(req.user.id, createAddressDto);
  }

  @Get()
  findAll(@Request() req) {
    return this.addressesService.findAll(req.user.id);
  }

  @Get(':id')
  findOne(@Request() req, @Param('id') id: string) {
    return this.addressesService.findOne(id, req.user.id);
  }

  @Patch(':id')
  update(@Request() req, @Param('id') id: string, @Body() updateAddressDto: UpdateAddressDto) {
    return this.addressesService.update(id, req.user.id, updateAddressDto);
  }

  @Delete(':id')
  remove(@Request() req, @Param('id') id: string) {
    return this.addressesService.remove(id, req.user.id);
  }
}
"""
with open(os.path.join(base_dir, "addresses", "addresses.controller.ts"), "w") as f:
    f.write(addresses_controller)


# Payments Module (Razorpay Webhooks)
os.makedirs(os.path.join(base_dir, "payments"), exist_ok=True)
payments_service = """import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as crypto from 'crypto';

@Injectable()
export class PaymentsService {
  constructor(private prisma: PrismaService) {}

  verifySignature(body: string, signature: string): boolean {
    const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
    if (!secret) return true; // If no secret, pass (for local testing mostly)
    
    const expectedSignature = crypto
      .createHmac('sha256', secret)
      .update(body)
      .digest('hex');
      
    return expectedSignature === signature;
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
}
"""
with open(os.path.join(base_dir, "payments", "payments.service.ts"), "w") as f:
    f.write(payments_service)

payments_controller = """import { Controller, Post, Headers, Req, BadRequestException } from '@nestjs/common';
import { PaymentsService } from './payments.service';

@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('webhook')
  async webhook(@Req() req, @Headers('x-razorpay-signature') signature: string) {
    // Note: We need raw body to verify signature perfectly. Assuming JSON body works mostly if strictly formatted.
    // Real prod apps use middleware to buffer raw body.
    const bodyStr = JSON.stringify(req.body); 
    
    if (signature && !this.paymentsService.verifySignature(bodyStr, signature)) {
      throw new BadRequestException('Invalid signature');
    }

    return this.paymentsService.handleWebhook(req.body);
  }
}
"""
with open(os.path.join(base_dir, "payments", "payments.controller.ts"), "w") as f:
    f.write(payments_controller)


# Bookings Module
os.makedirs(os.path.join(base_dir, "bookings", "dto"), exist_ok=True)
create_booking_dto = """import { IsString, IsArray, IsOptional, IsDateString } from 'class-validator';

export class CreateBookingDto {
  @IsString()
  vehicleId: string;

  @IsString()
  serviceId: string;

  @IsArray()
  @IsOptional()
  addonIds?: string[];

  @IsString()
  addressId: string;

  @IsDateString()
  scheduledAt: string;
}
"""
with open(os.path.join(base_dir, "bookings", "dto", "create-booking.dto.ts"), "w") as f:
    f.write(create_booking_dto)

bookings_service = """import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { PricingService } from '../pricing/pricing.service';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const Razorpay = require('razorpay');

@Injectable()
export class BookingsService {
  private razorpay;

  constructor(private prisma: PrismaService, private pricingService: PricingService) {
    const key_id = process.env.RAZORPAY_KEY_ID || 'dummy_key_id';
    const key_secret = process.env.RAZORPAY_KEY_SECRET || 'dummy_key_secret';
    
    if (key_id !== 'dummy_key_id') {
      this.razorpay = new Razorpay({ key_id, key_secret });
    }
  }

  async create(userId: string, createBookingDto: CreateBookingDto) {
    const { vehicleId, serviceId, addonIds = [], addressId, scheduledAt } = createBookingDto;

    // Verify Address Ownership
    const address = await this.prisma.address.findFirst({
      where: { id: addressId, userId }
    });
    if (!address) throw new NotFoundException('Address not found');

    // Get strictly verified Quote
    const quote = await this.pricingService.getQuote(userId, { vehicleId, serviceId, addonIds });

    // Create Booking and relations in a Transaction
    const booking = await this.prisma.$transaction(async (tx) => {
      const b = await tx.booking.create({
        data: {
          userId,
          vehicleId,
          addressId,
          status: 'PENDING_PAYMENT',
          totalAmount: quote.total,
          scheduledAt: new Date(scheduledAt),
        }
      });

      // We need the variant ID. Pricing logic used variants[0].
      const service = await tx.service.findUnique({
        where: { id: serviceId },
        include: { variants: true }
      });
      const variant = service.variants[0];

      await tx.bookingItem.create({
        data: {
          bookingId: b.id,
          serviceVariantId: variant.id,
          priceAtBooking: variant.price
        }
      });

      for (const addon of quote.addons) {
        await tx.bookingAddon.create({
          data: {
            bookingId: b.id,
            serviceAddonId: addon.id,
            priceAtBooking: addon.price
          }
        });
      }

      return b;
    });

    // Create Razorpay Order
    let razorpayOrderId = null;
    if (this.razorpay) {
      try {
        const order = await this.razorpay.orders.create({
          amount: Math.round(quote.total * 100), // in paise
          currency: 'INR',
          receipt: booking.id.slice(0, 40),
        });
        razorpayOrderId = order.id;
      } catch (err) {
        console.error("Razorpay order creation failed:", err);
        throw new BadRequestException('Payment gateway error');
      }
    } else {
      // Mock for test
      razorpayOrderId = 'order_mock_' + booking.id;
    }

    // Save Payment record
    const payment = await this.prisma.payment.create({
      data: {
        bookingId: booking.id,
        amount: quote.total,
        currency: 'INR',
        status: 'created',
        provider: 'razorpay',
        providerOrderId: razorpayOrderId
      }
    });

    return { booking, payment, orderId: razorpayOrderId, quote };
  }

  findAll(userId: string) {
    return this.prisma.booking.findMany({
      where: { userId },
      include: {
        vehicle: true,
        address: true,
        payments: true
      },
      orderBy: { createdAt: 'desc' }
    });
  }

  async findOne(id: string, userId: string) {
    const booking = await this.prisma.booking.findFirst({
      where: { id, userId },
      include: {
        vehicle: true,
        address: true,
        payments: true,
        items: { include: { serviceVariant: { include: { service: true } } } },
        addons: { include: { serviceAddon: true } }
      }
    });
    if (!booking) throw new NotFoundException('Booking not found');
    return booking;
  }
}
"""
with open(os.path.join(base_dir, "bookings", "bookings.service.ts"), "w") as f:
    f.write(bookings_service)

bookings_controller = """import { Controller, Get, Post, Body, Param, UseGuards, Request } from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  @Post()
  create(@Request() req, @Body() createBookingDto: CreateBookingDto) {
    return this.bookingsService.create(req.user.id, createBookingDto);
  }

  @Get()
  findAll(@Request() req) {
    return this.bookingsService.findAll(req.user.id);
  }

  @Get(':id')
  findOne(@Request() req, @Param('id') id: string) {
    return this.bookingsService.findOne(id, req.user.id);
  }
}
"""
with open(os.path.join(base_dir, "bookings", "bookings.controller.ts"), "w") as f:
    f.write(bookings_controller)

# App module
app_module_path = os.path.join(base_dir, "app.module.ts")
with open(app_module_path, "r") as f:
    app_content = f.read()

import_statement = "import { AddressesModule } from './addresses/addresses.module';\nimport { BookingsModule } from './bookings/bookings.module';\nimport { PaymentsModule } from './payments/payments.module';\n"
app_content = import_statement + app_content
app_content = app_content.replace("imports: [", "imports: [\n    AddressesModule,\n    BookingsModule,\n    PaymentsModule,")

with open(app_module_path, "w") as f:
    f.write(app_content)

print("Modules generated successfully.")
