import { IsString, IsArray, IsOptional, IsDateString } from 'class-validator';

export class CreateBookingDto {
  @IsString()
  @IsOptional()
  vehicleId?: string;

  @IsString()
  serviceId: string;

  @IsArray()
  @IsOptional()
  addonIds?: string[];

  @IsString()
  @IsOptional()
  addressId?: string;

  @IsDateString()
  scheduledAt: string;

  @IsString()
  @IsOptional()
  idempotencyKey?: string;

  @IsOptional()
  addressData?: {
    line1?: string;
    line2?: string;
    city?: string;
    state?: string;
    zipCode?: string;
    latitude?: number;
    longitude?: number;
  };
}
