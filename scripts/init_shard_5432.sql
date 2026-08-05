-- Shard 1 - Port 5432
\c postgres

DROP DATABASE IF EXISTS shardsql_shard_5432;
CREATE DATABASE shardsql_shard_5432;

\c shardsql_shard_5432

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

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

CREATE INDEX idx_shard_metadata_shard_id ON shard_metadata(shard_id);
CREATE INDEX idx_shard_data_shard_id ON shard_data(shard_id);

CREATE VIEW shard_stats AS
SELECT 
    sd.shard_id,
    COUNT(sd.id) as data_count,
    COUNT(DISTINCT CASE WHEN sd.updated_at > NOW() - INTERVAL '24 hours' THEN sd.id END) as recent_updates,
    MIN(sd.created_at) as first_record,
    MAX(sd.created_at) as last_record
FROM shard_data sd
GROUP BY sd.shard_id;

INSERT INTO shard_metadata (shard_id, shard_name)
VALUES (5432, 'Shard Database Port 5432');

COMMENT ON DATABASE shardsql_shard_5432 IS 'Sharded database instance for Shard 5432';

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;