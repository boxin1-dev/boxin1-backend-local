-- CreateEnum
CREATE TYPE "public"."Role" AS ENUM ('USER', 'ADMIN');

-- CreateEnum
CREATE TYPE "public"."OtpPurpose" AS ENUM ('EMAIL_VERIFICATION', 'PASSWORD_RESET', 'LOGIN_VERIFICATION');

-- CreateEnum
CREATE TYPE "public"."command_status_enum" AS ENUM ('pending', 'sent', 'acknowledged', 'failed', 'timeout');

-- CreateEnum
CREATE TYPE "public"."device_status_enum" AS ENUM ('normal', 'error', 'maintenance', 'standby');

-- CreateEnum
CREATE TYPE "public"."door_state_enum" AS ENUM ('open', 'closed');

-- CreateEnum
CREATE TYPE "public"."event_type_enum" AS ENUM ('discovery', 'connection', 'disconnection', 'command', 'error', 'warning', 'info');

-- CreateEnum
CREATE TYPE "public"."execution_status_enum" AS ENUM ('success', 'failed', 'partial');

-- CreateEnum
CREATE TYPE "public"."quality_enum" AS ENUM ('good', 'bad', 'uncertain', 'timeout');

-- CreateEnum
CREATE TYPE "public"."setting_type_enum" AS ENUM ('string', 'integer', 'boolean', 'json');

-- CreateEnum
CREATE TYPE "public"."severity_enum" AS ENUM ('low', 'medium', 'high', 'critical');

-- CreateEnum
CREATE TYPE "public"."trigger_type_enum" AS ENUM ('time', 'device_state', 'manual', 'webhook');

-- CreateEnum
CREATE TYPE "public"."user_role_enum" AS ENUM ('admin', 'user', 'guest');

-- CreateEnum
CREATE TYPE "public"."value_type_enum" AS ENUM ('boolean', 'integer', 'float', 'string', 'color');

-- CreateTable
CREATE TABLE "public"."users" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "username" TEXT,
    "firstName" TEXT,
    "lastName" TEXT,
    "isEmailVerified" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "role" "public"."Role" NOT NULL DEFAULT 'USER',
    "lastLogin" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."email_verifications" (
    "id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "email_verifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."password_resets" (
    "id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "used" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "password_resets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."otp_codes" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "purpose" "public"."OtpPurpose" NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "used" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."refresh_tokens" (
    "id" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."automation_scenarios" (
    "id" SERIAL NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "is_active" BOOLEAN DEFAULT true,
    "trigger_type" "public"."trigger_type_enum" NOT NULL,
    "trigger_config" JSONB NOT NULL,
    "actions" JSONB NOT NULL,
    "conditions" JSONB,
    "execution_count" INTEGER DEFAULT 0,
    "last_execution" TIMESTAMP(6),
    "last_execution_status" "public"."execution_status_enum",
    "created_by" VARCHAR(100),
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "automation_scenarios_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."capability_history" (
    "id" BIGSERIAL NOT NULL,
    "device_capability_id" INTEGER NOT NULL,
    "value" TEXT NOT NULL,
    "timestamp" TIMESTAMP(6) NOT NULL,
    "quality" "public"."quality_enum" DEFAULT 'good',
    "source" VARCHAR(100) DEFAULT 'mqtt',

    CONSTRAINT "capability_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."capability_types" (
    "id" SERIAL NOT NULL,
    "capability_code" VARCHAR(50) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "description" TEXT,
    "value_type" "public"."value_type_enum" NOT NULL,
    "unit" VARCHAR(20),
    "min_value" DECIMAL(15,6),
    "max_value" DECIMAL(15,6),
    "allowed_values" JSONB,
    "is_readable" BOOLEAN DEFAULT true,
    "is_writable" BOOLEAN DEFAULT false,
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "capability_types_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."device_capabilities" (
    "id" SERIAL NOT NULL,
    "device_id" INTEGER NOT NULL,
    "capability_code" VARCHAR(50) NOT NULL,
    "capability_name" VARCHAR(100) NOT NULL,
    "description" TEXT,
    "state_topic" VARCHAR(255) NOT NULL,
    "current_value" TEXT,
    "last_updated" TIMESTAMP(6),
    "is_visible" BOOLEAN DEFAULT true,
    "display_order" INTEGER DEFAULT 0,
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "capability_type_id" INTEGER,

    CONSTRAINT "device_capabilities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."device_commands" (
    "id" SERIAL NOT NULL,
    "device_id" INTEGER NOT NULL,
    "capability_code" VARCHAR(50),
    "command_name" VARCHAR(100) NOT NULL,
    "command_value" TEXT NOT NULL,
    "status" "public"."command_status_enum" DEFAULT 'pending',
    "sent_at" TIMESTAMP(6),
    "response_received_at" TIMESTAMP(6),
    "response_data" JSONB,
    "error_message" TEXT,
    "initiated_by" VARCHAR(100),
    "source_ip" INET,
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_commands_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."device_types" (
    "id" SERIAL NOT NULL,
    "type_code" VARCHAR(50) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "description" TEXT,
    "icon" VARCHAR(50),
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_types_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."locations" (
    "id" SERIAL NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "description" TEXT,
    "floor_level" INTEGER DEFAULT 0,
    "area_m2" DECIMAL(8,2),
    "icon" VARCHAR(50),
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "locations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."smartbox_devices" (
    "id" SERIAL NOT NULL,
    "device_id" VARCHAR(100) NOT NULL,
    "device_name" VARCHAR(200) NOT NULL,
    "device_type_code" VARCHAR(50) NOT NULL,
    "location_id" INTEGER,
    "ip_address" INET,
    "mac_address" macaddr,
    "firmware_version" VARCHAR(50),
    "manufacturer" VARCHAR(100) DEFAULT 'SmartBox',
    "discovery_topic" VARCHAR(255) NOT NULL,
    "command_topic" VARCHAR(255) NOT NULL,
    "status_topic" VARCHAR(255) NOT NULL,
    "is_online" BOOLEAN DEFAULT false,
    "last_seen" TIMESTAMP(6),
    "last_discovery" TIMESTAMP(6) NOT NULL,
    "connection_quality" INTEGER,
    "is_enabled" BOOLEAN DEFAULT true,
    "user_notes" TEXT,
    "created_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,
    "device_type_id" INTEGER,

    CONSTRAINT "smartbox_devices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."system_events" (
    "id" BIGSERIAL NOT NULL,
    "event_type" "public"."event_type_enum" NOT NULL,
    "device_id" INTEGER,
    "title" VARCHAR(200) NOT NULL,
    "description" TEXT,
    "event_data" JSONB,
    "severity" "public"."severity_enum" DEFAULT 'low',
    "timestamp" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "system_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."system_settings" (
    "id" SERIAL NOT NULL,
    "setting_key" VARCHAR(100) NOT NULL,
    "setting_value" TEXT,
    "setting_type" "public"."setting_type_enum" DEFAULT 'string',
    "description" TEXT,
    "is_user_configurable" BOOLEAN DEFAULT true,
    "updated_at" TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "system_settings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "public"."users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "email_verifications_token_key" ON "public"."email_verifications"("token");

-- CreateIndex
CREATE UNIQUE INDEX "password_resets_token_key" ON "public"."password_resets"("token");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_token_key" ON "public"."refresh_tokens"("token");

-- CreateIndex
CREATE INDEX "idx_active" ON "public"."automation_scenarios"("is_active");

-- CreateIndex
CREATE INDEX "idx_trigger_type" ON "public"."automation_scenarios"("trigger_type");

-- CreateIndex
CREATE INDEX "idx_capability_timestamp" ON "public"."capability_history"("device_capability_id", "timestamp" DESC);

-- CreateIndex
CREATE INDEX "idx_history_recent" ON "public"."capability_history"("timestamp" DESC);

-- CreateIndex
CREATE INDEX "idx_timestamp" ON "public"."capability_history"("timestamp");

-- CreateIndex
CREATE UNIQUE INDEX "capability_types_capability_code_key" ON "public"."capability_types"("capability_code");

-- CreateIndex
CREATE INDEX "idx_capabilities_visible" ON "public"."device_capabilities"("is_visible", "display_order");

-- CreateIndex
CREATE INDEX "idx_capability_code" ON "public"."device_capabilities"("capability_code");

-- CreateIndex
CREATE INDEX "idx_device_capabilities_type_id" ON "public"."device_capabilities"("capability_type_id");

-- CreateIndex
CREATE INDEX "idx_last_updated" ON "public"."device_capabilities"("last_updated");

-- CreateIndex
CREATE UNIQUE INDEX "device_capabilities_device_id_capability_code_key" ON "public"."device_capabilities"("device_id", "capability_code");

-- CreateIndex
CREATE INDEX "idx_created_at" ON "public"."device_commands"("created_at");

-- CreateIndex
CREATE INDEX "idx_device_status" ON "public"."device_commands"("device_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "device_types_type_code_key" ON "public"."device_types"("type_code");

-- CreateIndex
CREATE UNIQUE INDEX "smartbox_devices_device_id_key" ON "public"."smartbox_devices"("device_id");

-- CreateIndex
CREATE INDEX "idx_device_type" ON "public"."smartbox_devices"("device_type_code");

-- CreateIndex
CREATE INDEX "idx_devices_online_location" ON "public"."smartbox_devices"("is_online", "location_id");

-- CreateIndex
CREATE INDEX "idx_last_seen" ON "public"."smartbox_devices"("last_seen");

-- CreateIndex
CREATE INDEX "idx_location" ON "public"."smartbox_devices"("location_id");

-- CreateIndex
CREATE INDEX "idx_online_status" ON "public"."smartbox_devices"("is_online");

-- CreateIndex
CREATE INDEX "idx_smartbox_devices_type_id" ON "public"."smartbox_devices"("device_type_id");

-- CreateIndex
CREATE INDEX "idx_device_timestamp" ON "public"."system_events"("device_id", "timestamp" DESC);

-- CreateIndex
CREATE INDEX "idx_event_type" ON "public"."system_events"("event_type");

-- CreateIndex
CREATE INDEX "idx_events_recent" ON "public"."system_events"("timestamp" DESC, "event_type");

-- CreateIndex
CREATE INDEX "idx_severity_timestamp" ON "public"."system_events"("severity", "timestamp" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "system_settings_setting_key_key" ON "public"."system_settings"("setting_key");

-- AddForeignKey
ALTER TABLE "public"."email_verifications" ADD CONSTRAINT "email_verifications_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."password_resets" ADD CONSTRAINT "password_resets_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."otp_codes" ADD CONSTRAINT "otp_codes_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."refresh_tokens" ADD CONSTRAINT "refresh_tokens_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."capability_history" ADD CONSTRAINT "capability_history_device_capability_id_fkey" FOREIGN KEY ("device_capability_id") REFERENCES "public"."device_capabilities"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."device_capabilities" ADD CONSTRAINT "device_capabilities_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."smartbox_devices"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "public"."device_capabilities" ADD CONSTRAINT "fk_device_capabilities_capability_type" FOREIGN KEY ("capability_type_id") REFERENCES "public"."capability_types"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "public"."device_commands" ADD CONSTRAINT "device_commands_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."smartbox_devices"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "public"."smartbox_devices" ADD CONSTRAINT "fk_smartbox_devices_device_type" FOREIGN KEY ("device_type_id") REFERENCES "public"."device_types"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "public"."smartbox_devices" ADD CONSTRAINT "smartbox_devices_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "public"."system_events" ADD CONSTRAINT "system_events_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."smartbox_devices"("id") ON DELETE CASCADE ON UPDATE NO ACTION;
