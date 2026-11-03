import { Controller, Post, Body, Get, Delete, UseGuards, Request } from '@nestjs/common';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import { SendOtpDto, VerifyOtpDto } from './dto/otp.dto';
import { JwtAuthGuard } from './jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { generateRandomReferralCode } from '../rewards/referral-code.util';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService, private prisma: PrismaService) {}

  @Post('otp/send')
  sendOtp(@Body() dto: SendOtpDto) {
    return this.authService.sendOtp(dto);
  }

  @Post('otp/verify')
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto);
  }

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('social')
  socialLogin(@Body() dto: SocialLoginDto) {
    return this.authService.socialLogin(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('switch-mode')
  switchMode(@Request() req, @Body('role') role: 'CUSTOMER' | 'PARTNER') {
    return this.authService.switchMode(req.user.id, role);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async getMe(@Request() req) {
    let user: any = await this.prisma.user.findUnique({
      where: { id: req.user.id },
      include: {
        partnerApplication: {
          select: { id: true, applicationId: true, status: true, rejectionReason: true, createdAt: true },
        },
        partnerProfile: {
          select: { id: true, isActive: true, status: true },
        },
      },
    });
    if (user && !user.referralCode) {
      const candidateCode = generateRandomReferralCode();
      try {
        const updated = await this.prisma.user.update({
          where: { id: user.id },
          data: { referralCode: candidateCode },
        });
        if (updated?.referralCode) {
          user = updated;
        }
      } catch (_) {
        try {
          const recheck = await this.prisma.user.findUnique({ where: { id: user.id } });
          if (recheck?.referralCode) {
            user = recheck;
          }
        } catch (_) {}
      }
    }
    const { password, ...result } = user;
    return result;
  }

  @UseGuards(JwtAuthGuard)
  @Delete('me')
  async deleteAccount(@Request() req) {
    return this.authService.deleteAccount(req.user.id);
  }
}
