import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AddonsService {
  constructor(private prisma: PrismaService) {}

  findAll() {
    return this.prisma.serviceAddon.findMany();
  }
}
