import { IsString, IsOptional } from 'class-validator';

export class CreateVehicleDto {
  @IsOptional()
  @IsString()
  vehicleTypeId?: string;

  @IsOptional()
  @IsString()
  make?: string;

  @IsOptional()
  @IsString()
  brand?: string;

  @IsString()
  model: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  licensePlate?: string;

  @IsOptional()
  @IsString()
  registration_number?: string;

  @IsOptional()
  variant?: string;

  @IsOptional()
  color?: string;

  @IsOptional()
  is_primary?: boolean;
}
