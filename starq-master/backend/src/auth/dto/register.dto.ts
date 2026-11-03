import {
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  Matches,
  MinLength,
} from 'class-validator';

export class RegisterDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(6)
  password: string;

  @IsString()
  @IsNotEmpty()
  fullName: string;

  @IsString()
  @IsOptional()
  phone?: string;

  @IsString()
  @IsOptional()
  @Length(4, 20, { message: 'Referral code must be between 4 and 20 characters' })
  @Matches(/^[a-zA-Z0-9]+$/, { message: 'Referral code must contain only alphanumeric characters' })
  referralCode?: string;
}
