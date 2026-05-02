-- Civic-Link DPI Database Initialization
-- This script runs on container first startup

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Set up PostGIS with SRID 4326 (WGS 84 - standard GPS coordinates)
-- Geography type uses 4326 by default for accurate earth-surface calculations

-- Create schema for application
CREATE SCHEMA IF NOT EXISTS civic_link;

-- Grant permissions (these will be set after user creation in entrypoint)
-- ALTER DATABASE civic_link SET search_path TO civic_link, public;
