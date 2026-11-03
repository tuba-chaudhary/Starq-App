import { Controller, Get } from '@nestjs/common';
import { ReviewsService } from './reviews.service';

@Controller('reviews')
export class ReviewsController {
  constructor(private readonly service: ReviewsService) {}
  
  @Get()
  health() {
    return { status: 'ok', module: 'reviews' };
  }
}
