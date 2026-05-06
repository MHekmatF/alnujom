-- Migration 1: Init Enums
-- Phase 4 — Supabase Foundation (specs/004-supabase-foundation)
-- See: spec.md FR-011 (Q3 clarification — pre-declare every §6.3 enum); research.md R-03.

DO $$ BEGIN
  CREATE TYPE account_status_enum AS ENUM ('pending','approved','rejected','suspended','deleted');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE publisher_status_enum AS ENUM ('pending','approved','rejected','suspended','deleted');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE listing_status_enum AS ENUM ('draft','pending_review','approved','rejected','paused','sold','rented','expired','deleted');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE inquiry_status_enum AS ENUM ('new','seen','responded','closed','spam');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE report_status_enum AS ENUM ('new','reviewing','resolved','dismissed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE listing_purpose_enum AS ENUM ('sale','rent','daily_rent','investment');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE property_type_enum AS ENUM ('apartment','villa','land','shop','office','farm','warehouse','other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE location_visibility_enum AS ENUM ('hidden','approximate','exact','admin_only');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE report_reason_enum AS ENUM ('fake_listing','wrong_price','already_sold_or_rented','duplicate','spam','wrong_location','inappropriate_content','other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
