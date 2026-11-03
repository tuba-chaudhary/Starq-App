import { IsNotEmpty, IsEmail, IsString, IsEnum, Matches } from 'class-validator';
import { IdDocumentType } from '@prisma/client';

export class ApplyPartnerDto {
  @IsNotEmpty({ message: 'Full name is required' })
  @IsString()
  fullName: string;

  @IsNotEmpty({ message: 'Email address is required' })
  @IsEmail({}, { message: 'Invalid email address' })
  email: string;

  @IsNotEmpty({ message: 'Address is required' })
  @IsString()
  address: string;

  @IsNotEmpty({ message: 'City is required' })
  @IsString()
  city: string;

  @IsNotEmpty({ message: 'PIN code is required' })
  @Matches(/^\d{6}$/, { message: 'PIN code must be exactly 6 digits' })
  pinCode: string;

  @IsNotEmpty({ message: 'Identity document type is required' })
  @IsEnum(IdDocumentType, { message: 'Identity document must be AADHAAR or PAN' })
  idDocumentType: IdDocumentType;
}
