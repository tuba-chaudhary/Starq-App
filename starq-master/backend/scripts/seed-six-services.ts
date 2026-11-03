/**
 * STARQ — Safe, Repeatable Six-Service Catalog Insertion Script
 * 
 * SAFETY NOTICE:
 * - DO NOT EXECUTE AGAINST PRODUCTION WITHOUT EXPLICIT APPROVAL.
 * - By default, this script runs in DRY-RUN mode and performs ZERO database writes.
 * - When executed, it checks for existing records before inserting anything.
 * - It never overwrites existing records, prices, or historical data.
 * - It strictly preserves 'Basic Wash' and all historical bookings.
 * 
 * Usage:
 *   npx ts-node scripts/seed-six-services.ts           (Dry-run preview only, 0 writes)
 *   npx ts-node scripts/seed-six-services.ts --execute (Requires explicit confirmation)
 */

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export interface ProposedServiceDefinition {
  id: string;
  name: string;
  category: 'CAR' | 'BIKE';
  description: string;
  variant: {
    id: string;
    name: string;
    price: number;
    durationMins: number; // Proposed value subject to final user confirmation
  };
}

/**
 * Authoritative proposed catalog definitions for the six frontend services.
 * All IDs are stable, distinct UUID v4 strings.
 * Prices match displayed frontend prices.
 * Durations are proposed values subject to review before production insertion.
 */
export const SIX_SERVICE_DEFINITIONS: ProposedServiceDefinition[] = [
  {
    id: 'a0000001-0000-4000-8000-000000000001',
    name: 'Exterior Wash',
    category: 'CAR',
    description: 'Full exterior rinse, foam wash, and hand dry. Removes dust, dirt, and surface grime.',
    variant: {
      id: 'b0000001-0000-4000-8000-000000000001',
      name: 'Default',
      price: 249.0,
      durationMins: 45, // Proposed duration
    },
  },
  {
    id: 'a0000002-0000-4000-8000-000000000002',
    name: 'Interior Cleaning',
    category: 'CAR',
    description: 'Deep interior cleaning with vacuuming and surface care. Removes dust, stains, dirt, and unpleasant odours.',
    variant: {
      id: 'b0000002-0000-4000-8000-000000000002',
      name: 'Default',
      price: 399.0,
      durationMins: 60, // Proposed duration
    },
  },
  {
    id: 'a0000003-0000-4000-8000-000000000003',
    name: 'Full Detailing',
    category: 'CAR',
    description: "Complete interior and exterior detailing with deep cleaning, polishing, and protective treatment. Restores the vehicle's shine while refreshing and protecting the cabin.",
    variant: {
      id: 'b0000003-0000-4000-8000-000000000003',
      name: 'Default',
      price: 999.0,
      durationMins: 120, // Proposed duration
    },
  },
  {
    id: 'a0000004-0000-4000-8000-000000000004',
    name: 'Premium Wash',
    category: 'CAR',
    description: "Complete exterior and interior cleaning with polishing and a protective finish. Removes tough dirt, dust, stains, and restores the vehicle's shine.",
    variant: {
      id: 'b0000004-0000-4000-8000-000000000004',
      name: 'Default',
      price: 1299.0,
      durationMins: 90, // Proposed duration
    },
  },
  {
    id: 'a0000005-0000-4000-8000-000000000005',
    name: 'Bucket Wash',
    category: 'BIKE',
    description: 'A quick and thorough manual wash using bucket and soap. Perfect for regular upkeep and everyday grime.',
    variant: {
      id: 'b0000005-0000-4000-8000-000000000005',
      name: 'Default',
      price: 299.0,
      durationMins: 20, // Proposed duration
    },
  },
  {
    id: 'a0000006-0000-4000-8000-000000000006',
    name: 'Pressure Wash',
    category: 'BIKE',
    description: 'High-pressure water jet wash that removes tough dirt and grime from every corner of the bike.',
    variant: {
      id: 'b0000006-0000-4000-8000-000000000006',
      name: 'Default',
      price: 399.0,
      durationMins: 30, // Proposed duration
    },
  },
];

async function run() {
  const isExecute = process.argv.includes('--execute');

  console.log('================================================================');
  console.log(' STARQ — Six-Service Catalog Safe Insertion Script');
  console.log(` Mode: ${isExecute ? 'EXECUTE (WRITES ENABLED)' : 'DRY-RUN (NO WRITES WILL OCCUR)'}`);
  console.log('================================================================');

  if (!isExecute) {
    console.log('Notice: Running in preview mode. Pass --execute to apply changes.\n');
  }

  // 1. Inspect Vehicle Types
  const requiredVehicleTypes = ['CAR', 'BIKE'];
  for (const vtName of requiredVehicleTypes) {
    const existingVt = await prisma.vehicleType.findFirst({ where: { name: vtName } });
    if (existingVt) {
      console.log(`[OK] VehicleType '${vtName}' already exists (id: ${existingVt.id})`);
    } else {
      if (isExecute) {
        const createdVt = await prisma.vehicleType.create({ data: { name: vtName } });
        console.log(`[INSERTED] VehicleType '${vtName}' created (id: ${createdVt.id})`);
      } else {
        console.log(`[DRY-RUN] Would create missing VehicleType: '${vtName}'`);
      }
    }
  }

  console.log('\n--- Checking Catalog Services ---');

  let insertedCount = 0;
  let skippedCount = 0;

  for (const def of SIX_SERVICE_DEFINITIONS) {
    // Check if service already exists by ID or by (name, category)
    let existingService = await prisma.service.findUnique({
      where: { id: def.id },
      include: { variants: true },
    });

    if (!existingService) {
      existingService = await prisma.service.findFirst({
        where: { name: def.name, category: def.category },
        include: { variants: true },
      });
    }

    if (existingService) {
      skippedCount++;
      console.log(
        `[SKIPPED] Service '${def.name}' (${def.category}) already exists (id: ${existingService.id}). Existing record and prices preserved untouched.`
      );

      // Check variant
      const existingVariant = existingService.variants.find(
        (v) => v.id === def.variant.id || v.name === def.variant.name
      );
      if (existingVariant) {
        console.log(
          `  └─ [SKIPPED] Variant '${existingVariant.name}' exists (id: ${existingVariant.id}, price: ₹${existingVariant.price}). Preserved untouched.`
        );
      } else {
        if (isExecute) {
          const newVariant = await prisma.serviceVariant.create({
            data: {
              id: def.variant.id,
              serviceId: existingService.id,
              name: def.variant.name,
              price: def.variant.price,
              durationMins: def.variant.durationMins,
            },
          });
          console.log(
            `  └─ [INSERTED] Variant '${newVariant.name}' added to existing service (id: ${newVariant.id}, price: ₹${newVariant.price}).`
          );
        } else {
          console.log(
            `  └─ [DRY-RUN] Would insert variant '${def.variant.name}' for existing service (price: ₹${def.variant.price}, duration: ${def.variant.durationMins}m).`
          );
        }
      }
    } else {
      insertedCount++;
      if (isExecute) {
        const createdService = await prisma.service.create({
          data: {
            id: def.id,
            name: def.name,
            category: def.category,
            description: def.description,
          },
        });
        const createdVariant = await prisma.serviceVariant.create({
          data: {
            id: def.variant.id,
            serviceId: createdService.id,
            name: def.variant.name,
            price: def.variant.price,
            durationMins: def.variant.durationMins,
          },
        });
        console.log(
          `[INSERTED] Service '${createdService.name}' (${createdService.category}) created (id: ${createdService.id}).`
        );
        console.log(
          `  └─ [INSERTED] Variant '${createdVariant.name}' created (id: ${createdVariant.id}, price: ₹${createdVariant.price}, duration: ${createdVariant.durationMins}m).`
        );
      } else {
        console.log(
          `[DRY-RUN] Would insert Service '${def.name}' (${def.category}) with ID: ${def.id}`
        );
        console.log(
          `  └─ [DRY-RUN] Would insert Variant '${def.variant.name}' (price: ₹${def.variant.price}, duration: ${def.variant.durationMins}m) with ID: ${def.variant.id}`
        );
      }
    }
  }

  console.log('\n================================================================');
  console.log(` Summary: ${isExecute ? 'Executed' : 'Dry-run preview'}`);
  console.log(` - Services requiring insertion: ${insertedCount}`);
  console.log(` - Existing services preserved: ${skippedCount}`);
  console.log(` - Database writes performed: ${isExecute ? (insertedCount > 0 ? 'YES' : 'NONE') : '0 (DRY RUN)'}`);
  console.log('================================================================\n');
}

// Only execute standalone if invoked directly from CLI
if (require.main === module) {
  run()
    .catch((e) => {
      console.error('Error during catalog script execution:', e);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}
