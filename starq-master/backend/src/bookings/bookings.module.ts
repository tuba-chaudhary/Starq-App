import { Module } from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { BookingsController } from './bookings.controller';
import { PricingModule } from '../pricing/pricing.module';
import { PricingService } from '../pricing/pricing.service';

@Module({
  imports: [PricingModule],
  controllers: [BookingsController],
  providers: [BookingsService, PricingService],
})
export class BookingsModule {}
