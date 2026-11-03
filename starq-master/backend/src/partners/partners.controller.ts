import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  UseGuards,
  Request,
  UseInterceptors,
  UploadedFiles,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import { PartnersService } from './partners.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { UpdatePartnerStatusDto } from './dto/update-partner.dto';
import { ApplyPartnerDto } from './dto/apply-partner.dto';

@UseGuards(JwtAuthGuard)
@Controller('partners')
export class PartnersController {
  constructor(private readonly partnersService: PartnersService) {}

  @Post('apply')
  @UseInterceptors(
    FileFieldsInterceptor([
      { name: 'profilePhoto', maxCount: 1 },
      { name: 'idDocument', maxCount: 1 },
    ]),
  )
  apply(
    @Request() req,
    @Body() body: ApplyPartnerDto,
    @UploadedFiles()
    files: {
      profilePhoto?: Array<{ buffer: Buffer; originalname: string; mimetype: string }>;
      idDocument?: Array<{ buffer: Buffer; originalname: string; mimetype: string }>;
    },
  ) {
    const photo = files?.profilePhoto?.[0];
    const doc = files?.idDocument?.[0];
    return this.partnersService.applyPartner(req.user.id, body, photo, doc);
  }

  @Get('application-status')
  getApplicationStatus(@Request() req) {
    return this.partnersService.getApplicationStatus(req.user.id);
  }

  @UseGuards(RolesGuard)
  @Roles('PARTNER')
  @Patch('status')
  updateStatus(@Request() req, @Body() body: UpdatePartnerStatusDto) {
    return this.partnersService.updateStatus(req.user.id, body.status);
  }

  @UseGuards(RolesGuard)
  @Roles('PARTNER')
  @Get('bookings')
  getAssignedBookings(@Request() req) {
    return this.partnersService.getAssignedBookings(req.user.id);
  }

  @UseGuards(RolesGuard)
  @Roles('PARTNER')
  @Patch('bookings/:id/status')
  updateBookingStatus(@Request() req, @Param('id') bookingId: string, @Body('status') status: string) {
    return this.partnersService.updateBookingStatus(req.user.id, bookingId, status as any);
  }

  @UseGuards(RolesGuard)
  @Roles('PARTNER')
  @Patch('location')
  updateLocation(@Request() req, @Body() body: any) {
    return this.partnersService.updateLocation(req.user.id, body);
  }
}

