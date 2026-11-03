-- STARQ Customer & Service Partner Registration Migration
-- Safe, additive migration with existing-user backfill.
-- Note: Do NOT execute on production Neon database until explicit approval.

-- 1. Create Enums if they do not exist
DO $$ BEGIN
    CREATE TYPE "ApplicationStatus" AS ENUM ('PENDING_VERIFICATION', 'APPROVED', 'REJECTED', 'SUSPENDED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE "IdDocumentType" AS ENUM ('AADHAAR', 'PAN');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Add roles array column to "User" with default
ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "roles" "Role"[] NOT NULL DEFAULT ARRAY['CUSTOMER'::"Role"];

-- 3. Backfill existing users: populate "roles" from the existing "role" column
UPDATE "User"
SET "roles" = ARRAY["role"]
WHERE "roles" IS NULL OR "roles" = '{}' OR "roles" = ARRAY['CUSTOMER'::"Role"];

-- 4. Create PartnerApplication table
CREATE TABLE IF NOT EXISTS "PartnerApplication" (
    "id" TEXT NOT NULL,
    "applicationId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "fullName" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "pinCode" TEXT NOT NULL,
    "profilePhotoPath" TEXT NOT NULL,
    "idDocumentType" "IdDocumentType" NOT NULL,
    "idDocumentPath" TEXT NOT NULL,
    "status" "ApplicationStatus" NOT NULL DEFAULT 'PENDING_VERIFICATION',
    "rejectionReason" TEXT,
    "reviewedAt" TIMESTAMP(3),
    "reviewedById" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PartnerApplication_pkey" PRIMARY KEY ("id")
);

-- 5. Unique constraints & Indexes
CREATE UNIQUE INDEX IF NOT EXISTS "PartnerApplication_applicationId_key" ON "PartnerApplication"("applicationId");
CREATE UNIQUE INDEX IF NOT EXISTS "PartnerApplication_userId_key" ON "PartnerApplication"("userId");
CREATE INDEX IF NOT EXISTS "PartnerApplication_status_idx" ON "PartnerApplication"("status");
CREATE INDEX IF NOT EXISTS "PartnerApplication_userId_idx" ON "PartnerApplication"("userId");

-- 6. Foreign Key Constraints
DO $$ BEGIN
    ALTER TABLE "PartnerApplication" ADD CONSTRAINT "PartnerApplication_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE "PartnerApplication" ADD CONSTRAINT "PartnerApplication_reviewedById_fkey" FOREIGN KEY ("reviewedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
