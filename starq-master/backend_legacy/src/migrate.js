require('dotenv').config();
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { createPool } = require('./db');

const CONSENT_BODY = `STARQ VEHICLE CONDITION & SERVICE CONSENT
Version 1.0
*** MARKED FOR LEGAL REVIEW — THIS IS NOT FINAL LEGAL COPY. DO NOT TREAT AS A WAIVER OF LIABILITY. ***

I confirm that:
1. I am authorised to request washing/cleaning on this vehicle.
2. I have described known existing damage, marks, stains, chips, dents, and mechanical issues that may be relevant to this service.
3. Any photographs and notes I submit are an accurate record of the vehicle's condition at the time of this acknowledgement.
4. STARQ and assigned partners will take reasonable professional care while performing the booked service.
5. This acknowledgement does not waive claims for damage caused by proven negligence, unsafe practices, or failure to follow STARQ operating procedures.
6. STARQ is not automatically responsible for pre-existing conditions documented here, or for issues that cannot reasonably be attributed to this service.
7. I consent to STARQ storing this record, related photos, timestamps, booking identifiers, and partner assignment data for service delivery and dispute investigation.

Legal review required before production use.`;

async function migrate(pool) {
  const schema = fs.readFileSync(path.join(__dirname, '../migrations/001_schema.sql'), 'utf8');
  await pool.query(schema);
  await seed(pool);
}

async function seed(pool) {
  const { rows: existing } = await pool.query('SELECT id FROM users WHERE email = $1', ['admin@starq.in']);
  if (existing.length) return;

  const adminHash = await bcrypt.hash('Admin@12345', 10);
  const partnerHash = await bcrypt.hash('Partner@123', 10);

  const admin = await pool.query(
    `INSERT INTO users (phone, email, password_hash, full_name, role)
     VALUES ('9990000001', 'admin@starq.in', $1, 'STARQ Admin', 'admin') RETURNING id`,
    [adminHash],
  );

  const types = [
    ['hatchback', 'Hatchback', 'car', 1],
    ['sedan', 'Sedan', 'car', 2],
    ['suv', 'SUV', 'car', 3],
    ['muv', 'MUV', 'car', 4],
    ['luxury', 'Luxury', 'car', 5],
    ['bike', 'Bike', 'bike', 6],
  ];
  for (const t of types) {
    await pool.query(
      'INSERT INTO vehicle_types (code, label, kind, sort_order) VALUES ($1,$2,$3,$4) ON CONFLICT (code) DO NOTHING',
      t,
    );
  }

  const pincodes = [
    ['Noida Sector 62', '201309', 'Noida'],
    ['Noida Sector 18', '201301', 'Noida'],
    ['Noida Sector 50', '201307', 'Noida'],
    ['Noida Sector 15', '201301', 'Noida'],
    ['Noida Sector 137', '201304', 'Noida'],
  ];
  const areaIds = [];
  for (const a of pincodes) {
    const r = await pool.query(
      'INSERT INTO service_areas (name, pincode, city) VALUES ($1,$2,$3) RETURNING id',
      a,
    );
    areaIds.push(r.rows[0].id);
  }

  const partnerUsers = [
    ['9990000101', 'partner1@starq.in', 'Rahul Kumar'],
    ['9990000102', 'partner2@starq.in', 'Priya Singh'],
    ['9990000103', 'partner3@starq.in', 'Amit Verma'],
  ];
  const partnerIds = [];
  for (let i = 0; i < partnerUsers.length; i++) {
    const [phone, email, name] = partnerUsers[i];
    const u = await pool.query(
      `INSERT INTO users (phone, email, password_hash, full_name, role)
       VALUES ($1,$2,$3,$4,'service_partner') RETURNING id`,
      [phone, email, partnerHash, name],
    );
    const p = await pool.query(
      `INSERT INTO partners (user_id, assigned_service_area_id, is_online, is_available, status)
       VALUES ($1,$2,true,true,'available') RETURNING id`,
      [u.rows[0].id, areaIds[i % areaIds.length]],
    );
    partnerIds.push(p.rows[0].id);
    for (let d = 0; d < 7; d++) {
      await pool.query(
        `INSERT INTO partner_availability (partner_id, weekday, start_time, end_time)
         VALUES ($1,$2,'08:00','20:00')`,
        [p.rows[0].id, d],
      );
    }
  }

  const carServices = [
    ['basic-wash-car', 'Basic Wash', 'car', 'Full exterior rinse, foam wash, and hand dry.', 249, 45, 'exterior_wash.png', 1],
    ['deluxe-clean-car', 'Deluxe / Deep Clean', 'car', 'Interior vacuum, dashboard wipe, and deeper cabin cleaning.', 399, 60, 'interior_cleaning.png', 2],
    ['premium-wash-car', 'Premium Wash', 'car', 'Premium exterior and interior care with extra finishing.', 1299, 90, 'premium_wash.png', 3],
    ['polish-detailing-car', 'Polish / Detailing', 'car', 'Full detailing with polish, interiors, and finishing.', 999, 120, 'full_detailing.png', 4],
  ];
  const bikeServices = [
    ['basic-wash-bike', 'Basic Wash', 'bike', 'Bucket wash for bikes with chain-safe cleaning.', 149, 20, 'Bike_Bucket_wash.png', 1],
    ['deluxe-clean-bike', 'Deluxe / Deep Clean', 'bike', 'Pressure wash with detailed panel cleaning.', 199, 30, 'Bike_Pressure_Wash.png', 2],
    ['premium-wash-bike', 'Premium Wash', 'bike', 'Premium bike wash with extra shine care.', 349, 45, 'Bike_Pressure_Wash.png', 3],
    ['polish-detailing-bike', 'Polish / Detailing', 'bike', 'Polish and detailing for bikes and super commuters.', 499, 60, 'Bike_Bucket_wash.png', 4],
  ];

  const multipliers = { hatchback: 1, sedan: 1.15, suv: 1.35, muv: 1.4, luxury: 1.8, bike: 1 };

  async function insertService(s) {
    const r = await pool.query(
      `INSERT INTO services (slug, name, target_vehicle_type, description, base_price, duration_minutes, image_asset_path, sort_order)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
      s,
    );
    const id = r.rows[0].id;
    const cats = s[2] === 'bike' ? ['bike'] : ['hatchback', 'sedan', 'suv', 'muv', 'luxury'];
    for (const c of cats) {
      const price = Math.round(Number(s[4]) * multipliers[c]);
      await pool.query(
        `INSERT INTO service_variants (service_id, vehicle_category, price, duration_minutes)
         VALUES ($1,$2,$3,$4)`,
        [id, c, price, s[5]],
      );
    }
    const features = s[2] === 'bike'
      ? ['Body wash', 'Wheel clean', 'Chain-safe rinse', 'Wipe dry']
      : ['High-pressure rinse', 'Wheel cleaning', 'Window cleaning', 'Foam application', 'Hand dry'];
    for (let i = 0; i < features.length; i++) {
      await pool.query(
        `INSERT INTO service_features (service_id, section_name, feature_text, sort_order)
         VALUES ($1,'Included',$2,$3)`,
        [id, features[i], i],
      );
    }
    return id;
  }

  for (const s of [...carServices, ...bikeServices]) {
    await insertService(s);
  }

  const addons = [
    ['Freshener', 'Cabin air freshener', 10, 'both'],
    ['Tissue Box', 'Complimentary tissue box', 5, 'both'],
    ['Tyre Shine', 'Tyre dressing and shine', 15, 'both'],
    ['Interior Fragrance', 'Longer lasting interior fragrance', 10, 'car'],
  ];
  const addonBase = { Freshener: 49, 'Tissue Box': 39, 'Tyre Shine': 79, 'Interior Fragrance': 99 };
  for (const a of addons) {
    const r = await pool.query(
      `INSERT INTO service_addons (name, description, duration_minutes, applicable_vehicle_type)
       VALUES ($1,$2,$3,$4) RETURNING id`,
      a,
    );
    const cats = a[3] === 'car' ? ['hatchback', 'sedan', 'suv', 'muv', 'luxury'] : ['hatchback', 'sedan', 'suv', 'muv', 'luxury', 'bike'];
    for (const c of cats) {
      const extra = c === 'luxury' ? 1.4 : c === 'suv' || c === 'muv' ? 1.2 : 1;
      const price = Math.round(addonBase[a[0]] * extra);
      await pool.query(
        `INSERT INTO addon_category_prices (addon_id, vehicle_category, price) VALUES ($1,$2,$3)`,
        [r.rows[0].id, c, price],
      );
    }
  }

  await pool.query(
    `INSERT INTO consent_versions (version, title, body, legal_review_status, is_active)
     VALUES ('1.0', 'Vehicle condition & service consent', $1, 'MARKED_FOR_LEGAL_REVIEW', true)`,
    [CONSENT_BODY],
  );

  await pool.query(
    `INSERT INTO rewards (name, points_cost, description) VALUES
     ('₹50 off next wash', 200, 'Redeem 200 STARQ points for ₹50 off'),
     ('₹150 off detailing', 500, 'Redeem 500 STARQ points for ₹150 off detailing')`,
  );

  void admin;
  void partnerIds;
}

async function run() {
  const pool = createPool();
  await migrate(pool);
  await pool.end();
  console.log('STARQ migrations complete');
}

if (require.main === module) {
  run().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}

module.exports = { migrate };
