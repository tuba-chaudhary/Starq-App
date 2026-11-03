import {
  Controller,
  Get,
  Query,
  UseGuards,
  Request,
  ParseIntPipe,
  DefaultValuePipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RewardsService } from './rewards.service';

@UseGuards(JwtAuthGuard)
@Controller('rewards')
export class RewardsController {
  constructor(private readonly rewardsService: RewardsService) {}

  /**
   * GET /api/v1/rewards/summary
   * Returns active points balance, expiring points info, and expired total.
   */
  @Get('summary')
  getSummary(@Request() req: any) {
    return this.rewardsService.getPointsSummary(req.user.id);
  }

  /**
   * GET /api/v1/rewards/balance
   * Alias for points balance summary.
   */
  @Get('balance')
  getBalance(@Request() req: any) {
    return this.rewardsService.getPointsSummary(req.user.id);
  }

  /**
   * GET /api/v1/rewards/history
   * Returns user's points ledger history.
   */
  @Get('history')
  getHistory(
    @Request() req: any,
    @Query('limit', new DefaultValuePipe(50), ParseIntPipe) limit: number,
  ) {
    return this.rewardsService.getPointsHistory(req.user.id, limit);
  }

  /**
   * GET /api/v1/rewards/referral-code
   * Gets or generates the authenticated customer's permanent referral code.
   */
  @Get('referral-code')
  getReferralCode(@Request() req: any) {
    return this.rewardsService.getOrCreateReferralCode(req.user.id);
  }

  /**
   * GET /api/v1/rewards/referrals
   * Returns referral performance summary and list of invited referees.
   */
  @Get('referrals')
  getReferrals(@Request() req: any) {
    return this.rewardsService.getReferralSummary(req.user.id);
  }

  /**
   * GET /api/v1/rewards/referral-summary
   * Alias for referral metrics summary.
   */
  @Get('referral-summary')
  getReferralSummary(@Request() req: any) {
    return this.rewardsService.getReferralSummary(req.user.id);
  }
}
