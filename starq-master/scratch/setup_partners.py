import os

base_dir = r"c:\Users\SIDDDIQUI TABISH\Downloads\STARQ\starq_app-\backend\src"

# Partners Module
os.makedirs(os.path.join(base_dir, "partners", "dto"), exist_ok=True)
create_partner_dto = """import { IsString, IsEnum, IsOptional } from 'class-validator';
import { PartnerStatus } from '@prisma/client';

export class UpdatePartnerStatusDto {
  @IsEnum(PartnerStatus)
  status: PartnerStatus;
}
"""
with open(os.path.join(base_dir, "partners", "dto", "update-partner.dto.ts"), "w") as f:
    f.write(create_partner_dto)

partners_service = """import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PartnerStatus } from '@prisma/client';

@Injectable()
export class PartnersService {
  constructor(private prisma: PrismaService) {}

  async updateStatus(userId: string, status: PartnerStatus) {
    const partner = await this.prisma.partner.findUnique({
      where: { userId },
    });
    if (!partner) throw new NotFoundException('Partner profile not found');

    return this.prisma.partner.update({
      where: { id: partner.id },
      data: { status },
    });
  }

  async getAssignedBookings(userId: string) {
    const partner = await this.prisma.partner.findUnique({
      where: { userId },
    });
    if (!partner) throw new NotFoundException('Partner profile not found');

    return this.prisma.booking.findMany({
      where: { partnerId: partner.id },
      include: {
        address: true,
        vehicle: true,
        user: { select: { fullName: true, phone: true } },
      },
      orderBy: { scheduledAt: 'asc' },
    });
  }

  async updateBookingStatus(userId: string, bookingId: string, status: any) {
    const partner = await this.prisma.partner.findUnique({
      where: { userId },
    });
    if (!partner) throw new NotFoundException('Partner profile not found');

    const booking = await this.prisma.booking.findFirst({
      where: { id: bookingId, partnerId: partner.id },
    });
    if (!booking) throw new NotFoundException('Booking not found or not assigned to you');

    const updated = await this.prisma.booking.update({
      where: { id: bookingId },
      data: { status },
    });
    
    await this.prisma.bookingStatusHistory.create({
        data: {
            bookingId: booking.id,
            status: status
        }
    });
    
    if (status === 'COMPLETED') {
       await this.prisma.partner.update({
           where: { id: partner.id },
           data: { status: 'AVAILABLE' }
       });
    }

    return updated;
  }
}
"""
with open(os.path.join(base_dir, "partners", "partners.service.ts"), "w") as f:
    f.write(partners_service)

partners_controller = """import { Controller, Get, Post, Body, Patch, Param, UseGuards, Request } from '@nestjs/common';
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
}
"""
with open(os.path.join(base_dir, "partners", "partners.controller.ts"), "w") as f:
    f.write(partners_controller)

partners_module = """import { Module } from '@nestjs/common';
import { PartnersService } from './partners.service';
import { PartnersController } from './partners.controller';

@Module({
  controllers: [PartnersController],
  providers: [PartnersService],
})
export class PartnersModule {}
"""
with open(os.path.join(base_dir, "partners", "partners.module.ts"), "w") as f:
    f.write(partners_module)

print("Generated partners module.")
