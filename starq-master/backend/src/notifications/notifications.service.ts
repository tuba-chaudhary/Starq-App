import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { initializeApp, getApps, cert } from 'firebase-admin/app';
import { getMessaging, MulticastMessage } from 'firebase-admin/messaging';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);
  private firebaseInitialized = false;

  constructor(private prisma: PrismaService) {
    this.initializeFirebase();
  }

  private initializeFirebase() {
    try {
      if (!getApps().length) {
        if (process.env.FIREBASE_PROJECT_ID) {
          initializeApp({
            credential: cert({
              projectId: process.env.FIREBASE_PROJECT_ID,
              clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
              privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
            }),
          });
          this.firebaseInitialized = true;
          this.logger.log('Firebase Admin initialized securely from env');
        } else {
          this.logger.warn('FIREBASE_PROJECT_ID not set. Push notifications will be persisted but not sent.');
        }
      } else {
        this.firebaseInitialized = true;
      }
    } catch (e) {
      this.logger.error('Failed to initialize Firebase Admin', e);
    }
  }

  async registerToken(userId: string, token: string, platform?: string) {
    if (!token) throw new Error('Token is required');

    return this.prisma.deviceToken.upsert({
      where: { token },
      update: { userId, platform, updatedAt: new Date() },
      create: { userId, token, platform },
    });
  }

  async getUserNotifications(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async markRead(userId: string, id: string) {
    const notif = await this.prisma.notification.findFirst({ where: { id, userId } });
    if (!notif) throw new NotFoundException('Notification not found');

    return this.prisma.notification.update({
      where: { id },
      data: { readAt: new Date() },
    });
  }

  async markAllRead(userId: string) {
    return this.prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
  }

  async sendNotification(userId: string, title: string, body: string, type: string, bookingId?: string, data?: any) {
    if (bookingId) {
      const recent = await this.prisma.notification.findFirst({
        where: {
          userId,
          bookingId,
          type,
          createdAt: { gte: new Date(Date.now() - 5 * 60000) },
        },
      });
      if (recent) {
        this.logger.debug(`Duplicate notification prevented for ${type} on booking ${bookingId}`);
        return null;
      }
    }

    const notification = await this.prisma.notification.create({
      data: {
        userId,
        bookingId,
        title,
        body,
        type,
        data: data || {},
      },
    });

    if (this.firebaseInitialized) {
      const tokens = await this.prisma.deviceToken.findMany({ where: { userId } });
      const fcmTokens = tokens.map((t) => t.token);

      if (fcmTokens.length > 0) {
        try {
          const payload: MulticastMessage = {
            tokens: fcmTokens,
            notification: {
              title,
              body,
            },
            data: {
              type,
              bookingId: bookingId || '',
              ...(data ? data : {}),
            },
          };
          const response = await getMessaging().sendEachForMulticast(payload);
          
          const tokensToRemove = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              const errCode = resp.error?.code;
              if (errCode === 'messaging/invalid-registration-token' || errCode === 'messaging/registration-token-not-registered') {
                tokensToRemove.push(fcmTokens[idx]);
              }
            }
          });

          if (tokensToRemove.length > 0) {
            await this.prisma.deviceToken.deleteMany({
              where: { token: { in: tokensToRemove } },
            });
          }
        } catch (error) {
          this.logger.error('Error sending FCM notification', error);
        }
      }
    }

    return notification;
  }
}
