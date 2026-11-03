require('dotenv').config();
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function checkConnection() {
  console.log('Testing connection to database...');
  try {
    await prisma.$connect();
    console.log('✔ Prisma client connected successfully.');
    
    // Non-destructive read-only check
    const queryResult = await prisma.$queryRaw`SELECT 1 as connected;`;
    console.log('✔ Safe read-only query passed (SELECT 1). Result:', queryResult);

    const userCount = await prisma.user.count();
    console.log(`✔ User table accessible. Existing user records count: ${userCount}`);
    console.log('✔ Database connection verified non-destructively.');
  } catch (error) {
    console.error('✖ Database connection check failed:');
    console.error(error.message);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

checkConnection();
