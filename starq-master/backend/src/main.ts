import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { rawBody: true });
  
  app.setGlobalPrefix('api/v1');
  
  // Security Headers
  app.use(helmet());

  // CORS Configuration
  const isProd = process.env.NODE_ENV === 'production';
  let corsOrigin: string | string[] = '*';
  
  if (isProd) {
    if (process.env.CORS_ORIGIN) {
      corsOrigin = process.env.CORS_ORIGIN.split(',').map(o => o.trim());
    } else {
      corsOrigin = []; // In strict production without CORS_ORIGIN, disallow all web origins. Native apps bypass this.
    }
  }

  app.enableCors({
    origin: corsOrigin,
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
    credentials: true,
  });

  app.useGlobalPipes(new ValidationPipe({ whitelist: true }));

  const config = new DocumentBuilder()
    .setTitle('STARQ API')
    .setDescription('STARQ Backend Foundation API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = process.env.PORT || 3000;
  await app.listen(port, '0.0.0.0');
  console.log(`STARQ API running on port ${port}`);
}
bootstrap();
