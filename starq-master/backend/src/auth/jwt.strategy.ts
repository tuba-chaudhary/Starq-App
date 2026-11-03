import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private configService: ConfigService, private prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET') || 'super_secret_key',
    });
  }

  async validate(payload: any) {
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: {
        partnerApplication: { select: { id: true, applicationId: true, status: true } },
      },
    });
    if (!user) throw new UnauthorizedException();
    const effectiveRoles = user.roles && user.roles.length > 0 ? user.roles : [user.role];
    return {
      id: user.id,
      email: user.email,
      role: user.role,
      roles: effectiveRoles,
      partnerApplication: user.partnerApplication,
    };
  }
}
