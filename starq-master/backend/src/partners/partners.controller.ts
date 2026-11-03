import { Controller, Get, Post, Body, Patch, Param, UseGuards, Request } from '@nestjs/common';
import { PartnersService } from './partners.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdatePartnerStatusDto } from './dto/update-partner.dto';
import { PartnerStatus } from '@prisma/client';

@UseGuards(JwtAuthGuard)
@Controller('partners')
export class PartnersController {
  constructor(private readonly partnersService: PartnersService) {}

  @Patch('status')
  updateStatus(@Request() req, @Body() body: UpdatePartnerStatusDto) {
    return this.partnersService.updateStatus(req.user.id, body.status);
  }

  @Get('bookings')
  getAssignedBookings(@Request() req) {
    return this.partnersService.getAssignedBookings(req.user.id);
  }

  @Patch('bookings/:id/status')
  updateBookingStatus(@Request() req, @Param('id') bookingId: string, @Body('status') status: string) {
    return this.partnersService.updateBookingStatus(req.user.id, bookingId, status as any);
  }

  @Patch('location')
  updateLocation(@Request() req, @Body() body: any) {
    return this.partnersService.updateLocation(req.user.id, body);
  }
}
