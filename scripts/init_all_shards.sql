-- Shardsql Master Initialization Script
-- This script provisions databases for all three database shards
-- Run this after Docker containers are started to initialize all shards

-- ============================================================
-- Shard 1 - Port 5432
-- ============================================================
-- Connect to PostgreSQL as postgres user
\c postgres

-- Drop existing database if it exists (for clean initialization)
DROP DATABASE IF EXISTS shardsql_shard_5432;

-- Create the shard database
CREATE DATABASE shardsql_shard_5432;

-- Connect to the new database
\c shardsql_shard_5432

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create basic tables for shard functionality
CREATE TABLE shard_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shard_id INTEGER NOT NULL,
    shard_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE shard_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shard_id INTEGER NOT NULL,
    data_key VARCHAR(255) NOT NULL,
    data_value TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (shard_id) REFERENCES shard_metadata(shard_id)
);

-- Create indexes for better performance
CREATE INDEX idx_shard_metadata_shard_id ON shard_metadata(shard_id);
CREATE INDEX idx_shard_data_shard_id ON shard_data(shard_id);

-- Create a view for shard statistics
CREATE VIEW shard_stats AS
SELECT 
    sd.shard_id,
    COUNT(sd.id) as data_count,
    COUNT(DISTINCT CASE WHEN sd.updated_at > NOW() - INTERVAL '24 hours' THEN sd.id END) as recent_updates,
    MIN(sd.created_at) as first_record,
    MAX(sd.created_at) as last_record
FROM shard_data sd
GROUP BY sd.shard_id;

-- Insert initial metadata for this shard
INSERT INTO shard_metadata (shard_id, shard_name)
VALUES (5432, 'Shard Database Port 5432');

-- Add a comment to the database
COMMENT ON DATABASE shardsql_shard_5432 IS 'Sharded database instance for Shard 5432';

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- ============================================================
-- Shard 2 - Port 5433
-- ============================================================
-- Switch to postgres database to create next shard
\c postgres

-- Drop existing database if it exists (for clean initialization)
DROP DATABASE IF EXISTS shardsql_shard_5433;

-- Create the shard database
CREATE DATABASE shardsql_shard_5433;

-- Connect to the new database
\c shardsql_shard_5433

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create basic tables for shard functionality
CREATE TABLE shard_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shard_id INTEGER NOT NULL,
    shard_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE shard_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shard_id INTEGER NOT NULL,
    data_key VARCHAR(255) NOT NULL,
    data_value TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (shard_id) REFERENCES shard_metadata(shard_id)
);

-- Create indexes for better performance
CREATE INDEX idx_shard_metadata_shard_id ON shard_metadata(shard_id);
CREATE INDEX idx_shard_data_shard_id ON shard_data(shard_id);

-- Create a view for shard statistics
CREATE VIEW shard_stats AS
SELECT 
    sd.shard_id,
    COUNT(sd.id) as data_count,
    COUNT(DISTINCT CASE WHEN sd.updated_at > NOW() - INTERVAL '24 hours' THEN sd.id END) as recent_updates,
    MIN(sd.created_at) as first_record,
    MAX(sd.created_at) as last_record
FROM shard_data sd
GROUP BY sd.shard_id;

-- Insert initial metadata for this shard
INSERT INTO shard_metadata (shard_id, shard_name)
VALUES (5433, 'Shard Database Port 5433');

-- Add a comment to the database
COMMENT ON DATABASE shardsql_shard_5433 IS 'Sharded database instance for Shard 5433';

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;

-- ============================================================
-- Shard 3 - Port 5434
-- ============================================================
-- Switch to postgres database to create next shard
\c postgres

-- Drop existing database if it exists (for clean initialization)
DROP DATABASE IF EXISTS shardsql_shard_5434;

-- Create the shard database
CREATE DATABASE shardsql_shard_5434;

-- Connect to the new database
\c shardsql_shard_5434

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create basic tables for shard functionality
CREATE TABLE shard_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shard_id INTEGER NOT NULL,
    shard_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE shard_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shard_id INTEGER NOT NULL,
    data_key VARCHAR(255) NOT NULL,
    data_value TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (shard_id) REFERENCES shard_metadata(shard_id)
);

-- Create indexes for better performance
CREATE INDEX idx_shard_metadata_shard_id ON shard_metadata(shard_id);
CREATE INDEX idx_shard_data_shard_id ON shard_data(shard_id);

-- Create a view for shard statistics
CREATE VIEW shard_stats AS
SELECT 
    sd.shard_id,
    COUNT(sd.id) as data_count,
    COUNT(DISTINCT CASE WHEN sd.updated_at > NOW() - INTERVAL '24 hours' THEN sd.id END) as recent_updates,
    MIN(sd.created_at) as first_record,
    MAX(sd.created_at) as last_record
FROM shard_data sd
GROUP BY sd.shard_id;

-- Insert initial metadata for this shard
INSERT INTO shard_metadata (shard_id, shard_name)
VALUES (5434, 'Shard Database Port 5434');

-- Add a comment to the database
COMMENT ON DATABASE shardsql_shard_5434 IS 'Sharded database instance for Shard 5434';

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;
