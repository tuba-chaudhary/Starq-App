import { Controller, Get, Patch, Param, Body, Query, UseGuards } from '@nestjs/common';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('bookings')
  async getBookings(@Query('status') status?: string, @Query('take') take?: string, @Query('skip') skip?: string) {
    return this.adminService.getBookings(status, take ? parseInt(take) : 50, skip ? parseInt(skip) : 0);
  }

  @Get('bookings/:id')
  async getBookingDetails(@Param('id') id: string) {
    return this.adminService.getBookingDetails(id);
  }

  @Get('partners')
  async getPartners() {
    return this.adminService.getPartners();
  }

  @Get('partners/:id')
  async getPartnerDetails(@Param('id') id: string) {
    return this.adminService.getPartnerDetails(id);
  }

  @Patch('bookings/:id/assign-partner')
  async assignPartner(@Param('id') id: string, @Body('partnerId') partnerId: string) {
    return this.adminService.manualAssignPartner(id, partnerId);
  }

  @Patch('bookings/:id/reassign-partner')
  async reassignPartner(@Param('id') id: string, @Body('partnerId') partnerId: string) {
    return this.adminService.reassignPartner(id, partnerId);
  }

  @Patch('bookings/:id/cancel')
  async cancelBooking(@Param('id') id: string) {
    return this.adminService.cancelBooking(id);
  }
}
