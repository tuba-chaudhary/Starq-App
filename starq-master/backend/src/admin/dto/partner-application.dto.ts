import { IsNotEmpty, IsString, IsOptional, IsEnum } from 'class-validator';
import { ApplicationStatus } from '@prisma/client';

export class RejectPartnerApplicationDto {
  @IsNotEmpty({ message: 'A rejection reason is mandatory when rejecting a partner application' })
  @IsString()
  rejectionReason: string;
}

export class PartnerApplicationFilterDto {
  @IsOptional()
  @IsEnum(ApplicationStatus)
  status?: ApplicationStatus;
}
