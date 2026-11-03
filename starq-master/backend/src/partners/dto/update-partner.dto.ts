import { IsString, IsEnum, IsOptional } from 'class-validator';
import { PartnerStatus } from '@prisma/client';

export class UpdatePartnerStatusDto {
  @IsEnum(PartnerStatus)
  status: PartnerStatus;
}
