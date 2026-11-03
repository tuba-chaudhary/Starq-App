import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';

@Injectable()
export class AddressesService {
  constructor(private prisma: PrismaService) {}

  create(userId: string, createAddressDto: CreateAddressDto) {
    return this.prisma.address.create({
      data: {
        userId,
        ...createAddressDto,
      },
    });
  }

  findAll(userId: string) {
    return this.prisma.address.findMany({
      where: {
        userId,
        OR: [
          { line2: null },
          { NOT: { line2: { startsWith: '[ARCHIVED]' } } },
        ],
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string, userId: string) {
    const address = await this.prisma.address.findFirst({
      where: { id, userId },
    });
    if (!address) throw new NotFoundException('Address not found');
    return address;
  }

  async update(id: string, userId: string, updateAddressDto: UpdateAddressDto) {
    const current = await this.findOne(id, userId); // ownership check
    const bookingCount = await this.prisma.booking.count({ where: { addressId: id } });
    if (bookingCount > 0) {
      // Preserve historic booking address snapshot: archive old address and create new one
      const existingLine2 = current.line2 || '';
      const archivedLine2 = existingLine2.startsWith('[ARCHIVED]')
        ? existingLine2
        : `[ARCHIVED] ${existingLine2}`.trim();
      await this.prisma.address.update({
        where: { id },
        data: { line2: archivedLine2 },
      });
      return this.prisma.address.create({
        data: {
          userId,
          line1: updateAddressDto.line1 ?? current.line1,
          line2: updateAddressDto.line2 ?? current.line2,
          city: updateAddressDto.city ?? current.city,
          state: updateAddressDto.state ?? current.state,
          zipCode: updateAddressDto.zipCode ?? current.zipCode,
          latitude: updateAddressDto.latitude ?? current.latitude,
          longitude: updateAddressDto.longitude ?? current.longitude,
        },
      });
    }
    return this.prisma.address.update({
      where: { id },
      data: updateAddressDto,
    });
  }

  async remove(id: string, userId: string) {
    const address = await this.findOne(id, userId); // ownership check
    const bookingCount = await this.prisma.booking.count({ where: { addressId: id } });
    if (bookingCount > 0) {
      // Cannot hard delete due to existing booking foreign key; archive to preserve historic snapshot
      const existingLine2 = address.line2 || '';
      const archivedLine2 = existingLine2.startsWith('[ARCHIVED]')
        ? existingLine2
        : `[ARCHIVED] ${existingLine2}`.trim();
      return this.prisma.address.update({
        where: { id },
        data: { line2: archivedLine2 },
      });
    }
    return this.prisma.address.delete({
      where: { id },
    });
  }
}
