import os

base_dir = r"c:\Users\SIDDDIQUI TABISH\Downloads\STARQ\starq_app-\backend\src"

# DTOs
os.makedirs(os.path.join(base_dir, "vehicles", "dto"), exist_ok=True)

create_vehicle_dto = """import { IsString, IsOptional } from 'class-validator';

export class CreateVehicleDto {
  @IsString()
  vehicleTypeId: string;

  @IsString()
  make: string;

  @IsString()
  model: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  licensePlate?: string;
}
"""
with open(os.path.join(base_dir, "vehicles", "dto", "create-vehicle.dto.ts"), "w") as f:
    f.write(create_vehicle_dto)

update_vehicle_dto = """import { PartialType } from '@nestjs/swagger';
import { CreateVehicleDto } from './create-vehicle.dto';

export class UpdateVehicleDto extends PartialType(CreateVehicleDto) {}
"""
with open(os.path.join(base_dir, "vehicles", "dto", "update-vehicle.dto.ts"), "w") as f:
    f.write(update_vehicle_dto)

vehicles_service = """import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';

@Injectable()
export class VehiclesService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, createVehicleDto: CreateVehicleDto) {
    return this.prisma.vehicle.create({
      data: {
        userId,
        ...createVehicleDto,
      },
    });
  }

  async findAll(userId: string) {
    return this.prisma.vehicle.findMany({
      where: { userId },
      include: { vehicleType: true },
    });
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
    return this.prisma.vehicle.update({
      where: { id },
      data: updateVehicleDto,
    });
  }

  async remove(id: string, userId: string) {
    await this.findOne(id, userId); // verify ownership
    return this.prisma.vehicle.delete({
      where: { id },
    });
  }
}
"""
with open(os.path.join(base_dir, "vehicles", "vehicles.service.ts"), "w") as f:
    f.write(vehicles_service)

vehicles_controller = """import { Controller, Get, Post, Body, Patch, Param, Delete, UseGuards, Request } from '@nestjs/common';
import { VehiclesService } from './vehicles.service';
import { CreateVehicleDto } from './dto/create-vehicle.dto';
import { UpdateVehicleDto } from './dto/update-vehicle.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@UseGuards(JwtAuthGuard)
@Controller('vehicles')
export class VehiclesController {
  constructor(private readonly vehiclesService: VehiclesService) {}

  @Post()
  create(@Request() req, @Body() createVehicleDto: CreateVehicleDto) {
    return this.vehiclesService.create(req.user.id, createVehicleDto);
  }

  @Get()
  findAll(@Request() req) {
    return this.vehiclesService.findAll(req.user.id);
  }

  @Get(':id')
  findOne(@Request() req, @Param('id') id: string) {
    return this.vehiclesService.findOne(id, req.user.id);
  }

  @Patch(':id')
  update(@Request() req, @Param('id') id: string, @Body() updateVehicleDto: UpdateVehicleDto) {
    return this.vehiclesService.update(id, req.user.id, updateVehicleDto);
  }

  @Delete(':id')
  remove(@Request() req, @Param('id') id: string) {
    return this.vehiclesService.remove(id, req.user.id);
  }
}
"""
with open(os.path.join(base_dir, "vehicles", "vehicles.controller.ts"), "w") as f:
    f.write(vehicles_controller)

services_service = """import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ServicesService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    return this.prisma.service.findMany({
      include: { variants: true },
    });
  }
}
"""
with open(os.path.join(base_dir, "services", "services.service.ts"), "w") as f:
    f.write(services_service)

services_controller = """import { Controller, Get } from '@nestjs/common';
import { ServicesService } from './services.service';

@Controller('services')
export class ServicesController {
  constructor(private readonly servicesService: ServicesService) {}

  @Get()
  findAll() {
    return this.servicesService.findAll();
  }
}
"""
with open(os.path.join(base_dir, "services", "services.controller.ts"), "w") as f:
    f.write(services_controller)

addons_service = """import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AddonsService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    return this.prisma.serviceAddon.findMany();
  }
}
"""
with open(os.path.join(base_dir, "addons", "addons.service.ts"), "w") as f:
    f.write(addons_service)

addons_controller = """import { Controller, Get } from '@nestjs/common';
import { AddonsService } from './addons.service';

@Controller('addons')
export class AddonsController {
  constructor(private readonly addonsService: AddonsService) {}

  @Get()
  findAll() {
    return this.addonsService.findAll();
  }
}
"""
with open(os.path.join(base_dir, "addons", "addons.controller.ts"), "w") as f:
    f.write(addons_controller)


os.makedirs(os.path.join(base_dir, "pricing"), exist_ok=True)
pricing_module = """import { Module } from '@nestjs/common';
import { PricingService } from './pricing.service';
import { PricingController } from './pricing.controller';

@Module({
  controllers: [PricingController],
  providers: [PricingService],
})
export class PricingModule {}
"""
with open(os.path.join(base_dir, "pricing", "pricing.module.ts"), "w") as f:
    f.write(pricing_module)

os.makedirs(os.path.join(base_dir, "pricing", "dto"), exist_ok=True)
quote_dto = """import { IsString, IsArray, IsOptional } from 'class-validator';

export class QuoteDto {
  @IsString()
  vehicleId: string;

  @IsString()
  serviceId: string;

  @IsArray()
  @IsOptional()
  addonIds?: string[];
}
"""
with open(os.path.join(base_dir, "pricing", "dto", "quote.dto.ts"), "w") as f:
    f.write(quote_dto)

pricing_service = """import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { QuoteDto } from './dto/quote.dto';

@Injectable()
export class PricingService {
  constructor(private prisma: PrismaService) {}

  async getQuote(userId: string, quoteDto: QuoteDto) {
    const { vehicleId, serviceId, addonIds = [] } = quoteDto;
    
    // Verify vehicle
    const vehicle = await this.prisma.vehicle.findFirst({
      where: { id: vehicleId, userId }
    });
    if (!vehicle) throw new NotFoundException('Vehicle not found or does not belong to user');

    // Verify service
    const service = await this.prisma.service.findUnique({
      where: { id: serviceId },
      include: { variants: true }
    });
    if (!service) throw new NotFoundException('Service not found');

    // Get base price (using Default variant for now)
    const variant = service.variants[0];
    if (!variant) throw new BadRequestException('Service has no variants configured');

    const basePrice = variant.price;
    
    let addonsTotal = 0;
    const validatedAddons = [];
    if (addonIds.length > 0) {
      const addons = await this.prisma.serviceAddon.findMany({
        where: { id: { in: addonIds } }
      });
      if (addons.length !== addonIds.length) {
        throw new BadRequestException('One or more invalid addons selected');
      }
      addons.forEach(a => {
        addonsTotal += a.price;
        validatedAddons.push({ id: a.id, name: a.name, price: a.price });
      });
    }

    const subtotal = basePrice + addonsTotal;
    const taxes = 0; // Assuming inclusive of taxes or flat 0 for now
    const total = subtotal + taxes;

    return {
      vehicleId,
      serviceId,
      serviceName: service.name,
      basePrice,
      addons: validatedAddons,
      addonsTotal,
      subtotal,
      taxes,
      total,
      currency: 'INR'
    };
  }
}
"""
with open(os.path.join(base_dir, "pricing", "pricing.service.ts"), "w") as f:
    f.write(pricing_service)

pricing_controller = """import { Controller, Post, Body, UseGuards, Request } from '@nestjs/common';
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
"""
with open(os.path.join(base_dir, "pricing", "pricing.controller.ts"), "w") as f:
    f.write(pricing_controller)

# App module
app_module_path = os.path.join(base_dir, "app.module.ts")
with open(app_module_path, "r") as f:
    app_content = f.read()

if "PricingModule" not in app_content:
    import_statement = "import { PricingModule } from './pricing/pricing.module';\n"
    app_content = import_statement + app_content
    app_content = app_content.replace("imports: [", "imports: [\n    PricingModule,")
    with open(app_module_path, "w") as f:
        f.write(app_content)

print("Backend modules scaffolded successfully.")
