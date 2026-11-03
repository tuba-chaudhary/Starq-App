import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcryptjs';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { SocialLoginDto } from './dto/social-login.dto';
import {
  normalizeReferralCode,
  isValidReferralCodeFormat,
  generateRandomReferralCode,
} from '../rewards/referral-code.util';

@Injectable()
export class AuthService {
  constructor(private prisma: PrismaService, private jwtService: JwtService) {}

  async register(dto: RegisterDto) {
    const existingUser = await this.prisma.user.findFirst({
      where: {
        OR: [
          { email: dto.email.trim().toLowerCase() },
          ...(dto.phone ? [{ phone: dto.phone.trim() }] : []),
        ],
      },
    });
    if (existingUser) {
      throw new ConflictException('Email or phone already in use');
    }

    // 1. Referral validation (if code is provided)
    let referrer: { id: string; email: string; phone: string | null } | null = null;
    let normalizedCode: string | null = null;

    if (dto.referralCode && dto.referralCode.trim().length > 0) {
      normalizedCode = normalizeReferralCode(dto.referralCode);

      if (!isValidReferralCodeFormat(normalizedCode)) {
        throw new BadRequestException(
          'Invalid referral code format. Code should start with STARQ (e.g. STARQ123)',
        );
      }

      referrer = await this.prisma.user.findUnique({
        where: { referralCode: normalizedCode },
        select: { id: true, email: true, phone: true },
      });

      if (!referrer) {
        throw new BadRequestException('Invalid or non-existent referral code');
      }

      // Check self-referral
      const isSelfEmail = dto.email.trim().toLowerCase() === referrer.email.trim().toLowerCase();
      const isSelfPhone = dto.phone && referrer.phone && dto.phone.trim() === referrer.phone.trim();
      if (isSelfEmail || isSelfPhone) {
        throw new BadRequestException('You cannot use your own referral code');
      }
    }

    const hashedPassword = await bcrypt.hash(dto.password, 10);

    // 2. Atomic user registration and referral record creation
    try {
      const user = await this.prisma.$transaction(async (tx) => {
        const candidateReferralCode = generateRandomReferralCode();
        const newUser = await tx.user.create({
          data: {
            email: dto.email.trim().toLowerCase(),
            password: hashedPassword,
            fullName: dto.fullName.trim(),
            phone: dto.phone ? dto.phone.trim() : null,
            referralCode: candidateReferralCode,
          },
        });

        if (referrer && normalizedCode) {
          await tx.referral.create({
            data: {
              referrerId: referrer.id,
              refereeId: newUser.id,
              referralCode: normalizedCode,
              status: 'PENDING',
            },
          });
        }

        return newUser;
      });

      return this.generateTokens(user);
    } catch (err: any) {
      if (err instanceof ConflictException || err instanceof BadRequestException) {
        throw err;
      }
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        const target = (err.meta as any)?.target;
        if (Array.isArray(target) && target.includes('email')) {
          throw new ConflictException('Email already in use');
        }
        if (Array.isArray(target) && target.includes('phone')) {
          throw new ConflictException('Phone already in use');
        }
        if (Array.isArray(target) && target.includes('refereeId')) {
          throw new ConflictException('A referral already exists for this customer');
        }
      }
      throw err;
    }
  }

  async login(dto: LoginDto) {
    const email = dto.email.trim().toLowerCase();
    let user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || !user.password) throw new UnauthorizedException('Invalid credentials');
    
    const isValid = await bcrypt.compare(dto.password, user.password);
    if (!isValid) throw new UnauthorizedException('Invalid credentials');
    
    if (!user.referralCode) {
      const candidateCode = generateRandomReferralCode();
      try {
        const updated = await this.prisma.user.update({
          where: { id: user.id },
          data: { referralCode: candidateCode },
        });
        if (updated?.referralCode) {
          user.referralCode = updated.referralCode;
        }
      } catch (_) {
        try {
          const recheck = await this.prisma.user.findUnique({ where: { id: user.id } });
          if (recheck?.referralCode) {
            user.referralCode = recheck.referralCode;
          }
        } catch (_) {}
      }
    }

    return this.generateTokens(user);
  }

  async socialLogin(dto: SocialLoginDto) {
    let user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user) {
      const candidateCode = generateRandomReferralCode();
      user = await this.prisma.user.create({
        data: {
          email: dto.email,
          fullName: dto.fullName,
          role: 'CUSTOMER',
          referralCode: candidateCode,
        }
      });
    } else if (!user.referralCode) {
      const candidateCode = generateRandomReferralCode();
      try {
        const updated = await this.prisma.user.update({
          where: { id: user.id },
          data: { referralCode: candidateCode },
        });
        if (updated?.referralCode) {
          user.referralCode = updated.referralCode;
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
    return this.generateTokens(user);
  }

  private generateTokens(user: any) {
    const payload = { sub: user.id, email: user.email, role: user.role };
    return {
      accessToken: this.jwtService.sign(payload),
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        role: user.role,
        phone: user.phone ?? null,
        referralCode: user.referralCode ?? null,
      }
    };
  }

  async deleteAccount(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    
    const anonymizedString = `del_${Date.now()}_${userId.substring(0, 5)}`;
    
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        email: `${anonymizedString}@deleted.starq.app`,
        phone: anonymizedString.substring(0, 15),
        fullName: 'Deleted User',
        password: '', 
      }
    });

    await this.prisma.deviceToken.deleteMany({ where: { userId } });

    return { success: true, message: 'Account deleted successfully. Financial records retained per legal requirements.' };
  }
}
