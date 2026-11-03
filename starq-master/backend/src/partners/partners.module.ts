import { Module } from '@nestjs/common';
import { PartnersService } from './partners.service';
import { PartnersController } from './partners.controller';
import { NotificationsModule } from '../notifications/notifications.module';
import { RewardsModule } from '../rewards/rewards.module';

@Module({
  imports: [NotificationsModule, RewardsModule],
  controllers: [PartnersController],
  providers: [PartnersService],
})
export class PartnersModule {}
