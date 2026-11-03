import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  VEHICLE_PACKAGE_PRICING,
  PACKAGE_DISPLAY_NAMES,
  resolvePackageTier,
  VehicleCategoryKey,
} from '../pricing/pricing.service';

@Injectable()
export class ServicesService {
  constructor(private prisma: PrismaService) {}

  async findAll(vehicleCategory?: string) {
    const services = await this.prisma.service.findMany({
      include: { variants: true },
    });

    if (!vehicleCategory || vehicleCategory.trim().length === 0) {
      return services;
    }

    const catUpper = vehicleCategory.trim().toUpperCase();

    return services
      .filter((service) => {
        if (catUpper === 'BIKE') {
          return service.category?.toUpperCase() === 'BIKE';
        }
        if (service.category?.toUpperCase() === 'BIKE') {
          return false;
        }
        const tier = resolvePackageTier(service);
        // Luxury category does NOT have Silver
        if (catUpper === 'LUXURY' && tier === 'SILVER') {
          return false;
        }
        return true;
      })
      .map((service) => {
        const tier = resolvePackageTier(service);
        let adaptedPrice = service.variants[0]?.price;
        let displayName = service.name;
        const key = catUpper as VehicleCategoryKey;

        if (tier && VEHICLE_PACKAGE_PRICING[key] && VEHICLE_PACKAGE_PRICING[key][tier] !== undefined) {
          adaptedPrice = VEHICLE_PACKAGE_PRICING[key][tier]!;
          displayName = PACKAGE_DISPLAY_NAMES[tier] || service.name;
        }

        const adaptedVariants = service.variants.map((v, idx) => {
          if (idx === 0 && adaptedPrice !== undefined) {
            return { ...v, price: adaptedPrice };
          }
          return v;
        });

        return {
          ...service,
          displayName,
          packageTier: tier,
          vehicleCategory: catUpper,
          variants: adaptedVariants,
        };
      });
  }
}
