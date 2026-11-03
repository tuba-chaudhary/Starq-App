import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { QuoteDto } from './dto/quote.dto';

export type VehicleCategoryKey = 'HATCHBACK' | 'SEDAN' | 'MUV' | 'SUV' | 'LUXURY';
export type PackageTier = 'SILVER' | 'GOLD' | 'DIAMOND' | 'PLATINUM';

export const VEHICLE_PACKAGE_PRICING: Record<VehicleCategoryKey, Partial<Record<PackageTier, number>>> = {
  HATCHBACK: {
    SILVER: 399,
    GOLD: 699,
    DIAMOND: 1099,
    PLATINUM: 2699,
  },
  SEDAN: {
    SILVER: 599,
    GOLD: 799,
    DIAMOND: 1199,
    PLATINUM: 3099,
  },
  MUV: {
    SILVER: 699,
    GOLD: 899,
    DIAMOND: 1399,
    PLATINUM: 3399,
  },
  SUV: {
    SILVER: 799,
    GOLD: 999,
    DIAMOND: 1499,
    PLATINUM: 3599,
  },
  LUXURY: {
    // Silver is explicitly not provided in screenshots and not available for Luxury
    GOLD: 1899,
    DIAMOND: 2599,
    PLATINUM: 5099,
  },
};

export const PACKAGE_DISPLAY_NAMES: Record<PackageTier, string> = {
  SILVER: 'Silver — Basic Wash',
  GOLD: 'Gold — Deluxe Wash',
  DIAMOND: 'Diamond — Premium Wash',
  PLATINUM: 'Platinum — Deep Cleaning (Interior + Exterior)',
};

export function resolvePackageTier(service: { id: string; name: string; category?: string }): PackageTier | null {
  const name = service.name.trim().toLowerCase();
  const id = service.id.toLowerCase();
  if (
    name.includes('basic wash') ||
    name.includes('exterior wash') ||
    name.includes('silver') ||
    id === '9eaa3c73-830c-402f-afae-106488ec19c6' ||
    id === 'a0000001-0000-4000-8000-000000000001'
  ) {
    return 'SILVER';
  }
  if (
    name.includes('deluxe wash') ||
    name.includes('interior cleaning') ||
    name.includes('gold') ||
    id === 'a0000002-0000-4000-8000-000000000002'
  ) {
    return 'GOLD';
  }
  if (
    name.includes('premium wash') ||
    name.includes('diamond') ||
    id === 'a0000004-0000-4000-8000-000000000004'
  ) {
    return 'DIAMOND';
  }
  if (
    name.includes('deep cleaning') ||
    name.includes('full detailing') ||
    name.includes('platinum') ||
    id === 'a0000003-0000-4000-8000-000000000003'
  ) {
    return 'PLATINUM';
  }
  return null;
}

@Injectable()
export class PricingService {
  constructor(private prisma: PrismaService) {}

  async getQuote(userId: string, quoteDto: QuoteDto) {
    const { vehicleId, serviceId, addonIds = [], vehicleCategory: explicitVehicleCategory } = quoteDto;

    // Verify service
    const service = await this.prisma.service.findUnique({
      where: { id: serviceId },
      include: { variants: true },
    });
    if (!service) throw new NotFoundException('Service not found');

    let vehicle: any = null;
    let resolvedCategory: string | null = null;

    if (vehicleId && vehicleId.trim().length > 0) {
      vehicle = await this.prisma.vehicle.findFirst({
        where: { id: vehicleId.trim(), userId },
        include: { vehicleType: true },
      });
      if (!vehicle) throw new NotFoundException('Vehicle not found or does not belong to user');

      resolvedCategory = (vehicle.category || vehicle.vehicleType?.name || 'CAR').toUpperCase();

      // If user passed both vehicleId and vehicleCategory, verify they match
      if (explicitVehicleCategory && explicitVehicleCategory.trim().length > 0) {
        const expCat = explicitVehicleCategory.trim().toUpperCase();
        if (resolvedCategory !== expCat && vehicle.vehicleType?.name?.toUpperCase() !== expCat) {
          throw new BadRequestException(
            `Selected vehicle category '${resolvedCategory}' does not match requested category '${expCat}'`
          );
        }
      }

      // Verify vehicle and service category compatibility (CAR vs BIKE)
      if (vehicle.vehicleType && service.category) {
        const vehicleTypeUpper = vehicle.vehicleType.name.toUpperCase();
        const serviceCategoryUpper = service.category.toUpperCase();
        if (vehicleTypeUpper !== serviceCategoryUpper) {
          throw new BadRequestException(
            `Service '${service.name}' (${service.category}) is not compatible with vehicle type '${vehicle.vehicleType.name}'`
          );
        }
      }
    } else if (explicitVehicleCategory && explicitVehicleCategory.trim().length > 0) {
      resolvedCategory = explicitVehicleCategory.trim().toUpperCase();
      const isBikeCategory = resolvedCategory === 'BIKE';
      const isCarService = service.category?.toUpperCase() === 'CAR';
      if (isBikeCategory && isCarService) {
        throw new BadRequestException(
          `Service '${service.name}' (${service.category}) is not compatible with vehicle type 'BIKE'`
        );
      }
      if (!isBikeCategory && service.category?.toUpperCase() === 'BIKE') {
        throw new BadRequestException(
          `Service '${service.name}' (${service.category}) is not compatible with car category '${resolvedCategory}'`
        );
      }
    }

    const packageTier = resolvePackageTier(service);

    // Rejection of incompatible package / vehicle category (e.g. Silver for Luxury)
    if (resolvedCategory === 'LUXURY' && packageTier === 'SILVER') {
      throw new BadRequestException('Silver package is not available for Luxury vehicles');
    }

    // Determine basePrice:
    let basePrice: number;
    let serviceDisplayName = service.name;

    const categoryKey = resolvedCategory as VehicleCategoryKey;
    if (
      packageTier &&
      categoryKey &&
      VEHICLE_PACKAGE_PRICING[categoryKey] &&
      VEHICLE_PACKAGE_PRICING[categoryKey][packageTier] !== undefined
    ) {
      basePrice = VEHICLE_PACKAGE_PRICING[categoryKey][packageTier]!;
      serviceDisplayName = PACKAGE_DISPLAY_NAMES[packageTier] || service.name;
    } else {
      const variant = service.variants?.[0];
      if (!variant) throw new BadRequestException('Service has no variants configured');
      basePrice = variant.price;
    }

    let addonsTotal = 0;
    const validatedAddons = [];
    if (addonIds.length > 0) {
      const addons = await this.prisma.serviceAddon.findMany({
        where: { id: { in: addonIds } },
      });
      if (addons.length !== addonIds.length) {
        throw new BadRequestException('One or more invalid addons selected');
      }
      addons.forEach((a) => {
        addonsTotal += a.price;
        validatedAddons.push({ id: a.id, name: a.name, price: a.price });
      });
    }

    const subtotal = basePrice + addonsTotal;
    const convenienceFee = 0; // zero convenience fee confirmed
    const taxes = 0; // Flat 0 / inclusive
    const total = subtotal + convenienceFee + taxes;

    return {
      vehicleId: vehicle?.id || null,
      serviceId,
      serviceName: serviceDisplayName,
      packageTier: packageTier || null,
      vehicleCategory: resolvedCategory || null,
      basePrice,
      addons: validatedAddons,
      addonsTotal,
      convenienceFee,
      subtotal,
      taxes,
      total,
      currency: 'INR',
    };
  }
}
