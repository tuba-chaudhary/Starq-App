import { PricingModule } from './pricing/pricing.module';
import { PrismaModule } from './prisma/prisma.module';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { VehiclesModule } from './vehicles/vehicles.module';
import { ServicesModule } from './services/services.module';
import { AddonsModule } from './addons/addons.module';
import { AddressesModule } from './addresses/addresses.module';
import { BookingsModule } from './bookings/bookings.module';
import { PaymentsModule } from './payments/payments.module';
import { ReviewsModule } from './reviews/reviews.module';
import { RewardsModule } from './rewards/rewards.module';
import { PartnersModule } from './partners/partners.module';
import { AssignmentsModule } from './assignments/assignments.module';
import { NotificationsModule } from './notifications/notifications.module';
import { AdminModule } from './admin/admin.module';
import { StorageModule } from './storage/storage.module';

import { Module, Controller, Get } from '@nestjs/common';

@Controller('health')
class HealthController {
  @Get()
  check() { return { ok: true, timestamp: new Date().toISOString() }; }
}

@Module({
  imports: [
    PricingModule,
    PrismaModule,
    ConfigModule.forRoot({ isGlobal: true }),
    AuthModule,
    UsersModule,
    VehiclesModule,
    ServicesModule,
    AddonsModule,
    AddressesModule,
    BookingsModule,
    PaymentsModule,
    ReviewsModule,
    RewardsModule,
    PartnersModule,
    AssignmentsModule,
    NotificationsModule,
    AdminModule,
    StorageModule,
  ],
  controllers: [HealthController],
  providers: [],
})
export class AppModule {}
