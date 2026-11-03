import { Controller, Post, Body, Get, Delete, UseGuards, Request } from '@nestjs/common';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import { JwtAuthGuard } from './jwt-auth.guard';
import { PrismaService } from '../prisma/prisma.service';
import { generateRandomReferralCode } from '../rewards/referral-code.util';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService, private prisma: PrismaService) {}

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
  @Get('me')
  async getMe(@Request() req) {
    let user = await this.prisma.user.findUnique({ where: { id: req.user.id } });
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
