import { Controller, Post, Body, UseGuards, Request } from '@nestjs/common';
import { PricingService } from './pricing.service';
import { QuoteDto } from './dto/quote.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('pricing')
export class PricingController {
  constructor(private readonly pricingService: PricingService) {}

  @Post('quote')
  getQuote(@Request() req, @Body() quoteDto: QuoteDto) {
    return this.pricingService.getQuote(req.user.id, quoteDto);
  }
}
