import { IsString, IsArray, IsOptional } from 'class-validator';

export class QuoteDto {
  @IsString()
  @IsOptional()
  vehicleId?: string;

  @IsString()
  serviceId: string;

  @IsString()
  @IsOptional()
  vehicleCategory?: string;

  @IsArray()
  @IsOptional()
  addonIds?: string[];
}
