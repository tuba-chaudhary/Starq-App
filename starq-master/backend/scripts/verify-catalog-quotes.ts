import { PrismaClient } from '@prisma/client';
import { PricingService } from '../src/pricing/pricing.service';

const prisma = new PrismaClient();
const pricing = new PricingService(prisma as any);

async function verify() {
  const userId = 'ad02b54f-5f47-4046-92de-cb2de4cfd6e2';
  const carVehicleId = '01e5e1d8-d73f-4415-aecb-a74448d8daaa';
  const bikeVehicleId = '31346a19-9449-413c-9e22-137178460516';

  const testCases = [
    { serviceId: 'a0000001-0000-4000-8000-000000000001', vehicleId: carVehicleId, expectedPrice: 249, name: 'Exterior Wash' },
    { serviceId: 'a0000002-0000-4000-8000-000000000002', vehicleId: carVehicleId, expectedPrice: 399, name: 'Interior Cleaning' },
    { serviceId: 'a0000003-0000-4000-8000-000000000003', vehicleId: carVehicleId, expectedPrice: 999, name: 'Full Detailing' },
    { serviceId: 'a0000004-0000-4000-8000-000000000004', vehicleId: carVehicleId, expectedPrice: 1299, name: 'Premium Wash' },
    { serviceId: 'a0000005-0000-4000-8000-000000000005', vehicleId: bikeVehicleId, expectedPrice: 299, name: 'Bucket Wash' },
    { serviceId: 'a0000006-0000-4000-8000-000000000006', vehicleId: bikeVehicleId, expectedPrice: 399, name: 'Pressure Wash' },
  ];

  console.log('--- VERIFYING QUOTES FOR ALL 6 SERVICES ---');
  for (const tc of testCases) {
    const q = await pricing.getQuote(userId, { vehicleId: tc.vehicleId, serviceId: tc.serviceId });
    console.log(`PASS: ${tc.name} -> Quoted Total: ₹${q.total} (Base: ₹${q.basePrice}, Taxes: ₹${q.taxes}, Addons: ₹${q.addonsTotal})`);
    if (q.total !== tc.expectedPrice) throw new Error(`Price mismatch on ${tc.name}`);
  }

  console.log('\n--- VERIFYING VEHICLE INCOMPATIBILITY REJECTIONS ---');
  // 1. Car vehicle with Bike service
  try {
    await pricing.getQuote(userId, { vehicleId: carVehicleId, serviceId: 'a0000005-0000-4000-8000-000000000005' });
    console.error('FAIL: Car vehicle should have been rejected for Bike service');
  } catch (err: any) {
    console.log(`PASS: Car vehicle rejected for Bike service: "${err.message}"`);
  }

  // 2. Bike vehicle with Car service
  try {
    await pricing.getQuote(userId, { vehicleId: bikeVehicleId, serviceId: 'a0000001-0000-4000-8000-000000000001' });
    console.error('FAIL: Bike vehicle should have been rejected for Car service');
  } catch (err: any) {
    console.log(`PASS: Bike vehicle rejected for Car service: "${err.message}"`);
  }
}

verify()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
