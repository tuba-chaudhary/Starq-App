import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigService, ConfigModule } from '@nestjs/config';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './jwt.strategy';
import { OtpService } from './otp/otp.service';
import { Fast2SmsOtpProvider } from './otp/providers/fast2sms.provider';
import { Msg91OtpProvider } from './otp/providers/msg91.provider';
import { DevMockOtpProvider } from './otp/providers/dev-mock.provider';

@Module({
  imports: [
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: async (configService: ConfigService) => ({
        secret: configService.get<string>('JWT_SECRET') || 'super_secret_key',
        signOptions: { expiresIn: '7d' },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    OtpService,
    Fast2SmsOtpProvider,
    Msg91OtpProvider,
    DevMockOtpProvider,
  ],
  exports: [AuthService, OtpService],
})
export class AuthModule {}

