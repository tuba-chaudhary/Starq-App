import { Controller, Get, Query } from '@nestjs/common';
import { ServicesService } from './services.service';

@Controller('services')
export class ServicesController {
  constructor(private readonly servicesService: ServicesService) {}

  @Get()
  findAll(@Query('vehicleCategory') vehicleCategory?: string) {
    return this.servicesService.findAll(vehicleCategory);
  }
}
