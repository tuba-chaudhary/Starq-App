import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';
import { isValidVehiclePlate, normalizeVehiclePlate } from './vehicle-plate.util';

@Injectable()
export class VehiclesService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, createVehicleDto: CreateVehicleDto) {
    const rawPlate = (createVehicleDto.licensePlate || createVehicleDto.registration_number || '').trim();
    if (!rawPlate) {
      throw new BadRequestException('Vehicle registration number / license plate is required');
    }
    if (!isValidVehiclePlate(rawPlate)) {
      throw new BadRequestException('Please enter a valid vehicle plate (e.g. MH 01 AB 1234 or DL 3C AB 1234)');
    }
    const licensePlate = normalizeVehiclePlate(rawPlate);

    const make = (createVehicleDto.make || createVehicleDto.brand || '').trim();
    if (!make) {
      throw new BadRequestException('Vehicle brand / make is required');
    }
    const model = (createVehicleDto.model || '').trim();
    if (!model) {
      throw new BadRequestException('Vehicle model is required');
    }

    let vehicleTypeId = createVehicleDto.vehicleTypeId;
    const cat = (createVehicleDto.category || 'CAR').toUpperCase();
    const isBike = cat.includes('BIKE') || cat.includes('SCOOTER');

    if (!vehicleTypeId) {
      const typeName = isBike ? 'BIKE' : 'CAR';
      let vt = await this.prisma.vehicleType.findFirst({
        where: { name: typeName },
      });
      if (!vt) {
        vt = await this.prisma.vehicleType.create({
          data: { name: typeName },
        });
      }
      vehicleTypeId = vt.id;
    }

    const category = createVehicleDto.category || (isBike ? 'BIKE' : 'HATCHBACK');

    const created = await this.prisma.vehicle.create({
      data: {
        userId,
        vehicleTypeId: vehicleTypeId,
        make,
        model,
        category,
        licensePlate,
      },
      include: { vehicleType: true },
    });

    return {
      status: 'success',
      data: created,
      ...created,
    };
  }

  async findAll(userId: string) {
    const list = await this.prisma.vehicle.findMany({
      where: {
        userId,
        NOT: {
          licensePlate: { startsWith: '[ARCHIVED]' },
        },
      },
      include: { vehicleType: true },
      orderBy: { createdAt: 'desc' },
    });
    return {
      status: 'success',
      data: list,
      vehicles: list,
    };
  }

  async findOne(id: string, userId: string) {
    const vehicle = await this.prisma.vehicle.findFirst({
      where: { id, userId },
      include: { vehicleType: true },
    });
    if (!vehicle) throw new NotFoundException('Vehicle not found');
    return vehicle;
  }

  async update(id: string, userId: string, updateVehicleDto: UpdateVehicleDto) {
    await this.findOne(id, userId); // verify ownership
    const data: any = { ...updateVehicleDto };
    const rawPlate = (updateVehicleDto.licensePlate || updateVehicleDto.registration_number || '').trim();
    if (rawPlate) {
      if (!isValidVehiclePlate(rawPlate)) {
        throw new BadRequestException('Please enter a valid vehicle plate (e.g. MH 01 AB 1234 or DL 3C AB 1234)');
      }
      data.licensePlate = normalizeVehiclePlate(rawPlate);
    }
    delete data.registration_number;
    delete data.brand;
    delete data.is_primary;
    return this.prisma.vehicle.update({
      where: { id },
      data,
    });
  }

  async remove(id: string, userId: string) {
    const vehicle = await this.findOne(id, userId); // verify ownership
    const bookingCount = await this.prisma.booking.count({ where: { vehicleId: id } });
    if (bookingCount > 0) {
      const existingPlate = vehicle.licensePlate || '';
      const archivedPlate = existingPlate.startsWith('[ARCHIVED]')
        ? existingPlate
        : `[ARCHIVED] ${existingPlate}`.trim();
      return this.prisma.vehicle.update({
        where: { id },
        data: { licensePlate: archivedPlate },
      });
    }
    return this.prisma.vehicle.delete({
      where: { id },
    });
  }
}
