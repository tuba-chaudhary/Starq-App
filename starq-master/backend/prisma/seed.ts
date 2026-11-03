import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  const vehicleTypes = ['CAR', 'BIKE'];
  for (const vt of vehicleTypes) {
    const existing = await prisma.vehicleType.findFirst({ where: { name: vt } });
    if (!existing) {
      await prisma.vehicleType.create({ data: { name: vt } });
      console.log(`Created vehicle type: ${vt}`);
    } else {
      console.log(`Skipped existing vehicle type: ${vt}`);
    }
  }

  const servicesData = [
    { name: 'Basic Wash', category: 'CAR', description: 'Exterior washing and cleaning', price: 299 },
    { name: 'Deep Clean / Deluxe', category: 'CAR', description: 'Deep interior and exterior wash', price: 599 },
    { name: 'Premium Wash', category: 'CAR', description: 'Premium washing with wax', price: 999 },
    { name: 'Polish / Detailing', category: 'CAR', description: 'Complete detailing and polish', price: 1999 },
    
    { name: 'Basic Wash', category: 'BIKE', description: 'Exterior washing and cleaning', price: 149 },
    { name: 'Deep Clean / Deluxe', category: 'BIKE', description: 'Deep wash', price: 299 },
    { name: 'Premium Wash', category: 'BIKE', description: 'Premium washing with wax', price: 499 },
    { name: 'Polish / Detailing', category: 'BIKE', description: 'Complete detailing and polish', price: 999 },
  ];

  for (const s of servicesData) {
    let srv = await prisma.service.findFirst({
      where: { name: s.name, category: s.category }
    });
    
    if (!srv) {
      srv = await prisma.service.create({
        data: { name: s.name, category: s.category, description: s.description }
      });
      await prisma.serviceVariant.create({
        data: { serviceId: srv.id, name: 'Default', price: s.price }
      });
      console.log(`Created service: ${s.name} (${s.category})`);
    } else {
      console.log(`Skipped existing service: ${s.name} (${s.category})`);
    }
  }

  const addonsData = [
    { name: 'Freshener', price: 49 },
    { name: 'Tissue Box', price: 99 },
    { name: 'Tyre Shine', price: 149 },
    { name: 'Interior Fragrance', price: 199 },
  ];

  for (const a of addonsData) {
    let addon = await prisma.serviceAddon.findFirst({
      where: { name: a.name }
    });
    
    if (!addon) {
      await prisma.serviceAddon.create({
        data: { name: a.name, price: a.price }
      });
      console.log(`Created addon: ${a.name}`);
    } else {
      console.log(`Skipped existing addon: ${a.name}`);
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
}).finally(async () => {
  await prisma.$disconnect();
});
