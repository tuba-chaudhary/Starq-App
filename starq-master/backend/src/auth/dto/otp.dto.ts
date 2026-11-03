import { IsNotEmpty, IsString, Matches, IsOptional, IsEnum } from 'class-validator';
import { Role } from '@prisma/client';

export class SendOtpDto {
  @IsNotEmpty({ message: 'Mobile number is required' })
  @IsString()
  @Matches(/^[6-9]\d{9}$/, {
    message: 'Please enter a valid 10-digit Indian mobile number starting with 6-9',
  })
  phone: string;
}

export class VerifyOtpDto {
  @IsNotEmpty({ message: 'Mobile number is required' })
  @IsString()
  @Matches(/^[6-9]\d{9}$/, {
    message: 'Please enter a valid 10-digit Indian mobile number starting with 6-9',
  })
  phone: string;

  @IsNotEmpty({ message: 'Verification code is required' })
  @IsString()
  @Matches(/^\d{6}$/, { message: 'Verification code must be 6 digits' })
  otp: string;

  @IsOptional()
  @IsString()
  fullName?: string;

  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsEnum(Role)
  intendedRole?: Role;
}
