import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
  Query,
  UseGuards,
  Request,
  Res,
} from '@nestjs/common';
import { Response } from 'express';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { ApplicationStatus } from '@prisma/client';
import { RejectPartnerApplicationDto } from './dto/partner-application.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('ADMIN')
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('partner-applications')
  async getPartnerApplications(@Query('status') status?: ApplicationStatus) {
    return this.adminService.getPartnerApplications(status);
  }

  @Get('partner-applications/:id')
  async getPartnerApplicationDetails(@Param('id') id: string) {
    return this.adminService.getPartnerApplicationDetails(id);
  }

  @Get('partner-applications/:id/document/:type')
  async getPartnerApplicationDocument(
    @Param('id') id: string,
    @Param('type') type: 'photo' | 'id-proof',
    @Res() res: Response,
  ) {
    const doc = await this.adminService.getPartnerApplicationDocument(id, type);
    res.setHeader('Content-Type', doc.mimeType);
    res.setHeader('Cache-Control', 'private, no-store, max-age=0');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    return res.sendFile(doc.filePath);
  }

  @Patch('partner-applications/:id/approve')
  async approvePartnerApplication(@Param('id') id: string, @Request() req) {
    return this.adminService.approvePartnerApplication(id, req.user.id);
  }

  @Patch('partner-applications/:id/reject')
  async rejectPartnerApplication(
    @Param('id') id: string,
    @Request() req,
    @Body() dto: RejectPartnerApplicationDto,
  ) {
    return this.adminService.rejectPartnerApplication(id, req.user.id, dto.rejectionReason);
  }

  @Patch('partner-applications/:id/suspend')
  async suspendPartnerApplication(@Param('id') id: string, @Request() req) {
    return this.adminService.suspendPartner(id, req.user.id);
  }

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
