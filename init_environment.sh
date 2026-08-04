#!/bin/bash

# Initialize a new local environment for the shardsql project
# This script sets up the project directory structure and initializes dependencies
# This script sets up the project directory structure and initializes dependencies

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -d "/Users/nalamkarthik/Documents/projects/shardsql" ]; then
    print_error "Project directory not found. Please run this script from the project root."
    exit 1
fi

# Check for Docker and Docker Compose
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not available. Please check your Docker installation."
    exit 1
fi

# Create project directory structure
create_directory_structure() {
    print_info "Creating project directory structure..."
    
    # Create main directories
    mkdir -p logs
    mkdir -p scripts
    mkdir -p configs
    mkdir -p data/postgres
    
    # Create subdirectories for each shard
    for shard_port in 5432 5433 5434; do
        mkdir -p "data/postgres/shard_${shard_port}"
    done
    
    print_info "Directory structure created successfully."
}

# Initialize PostgreSQL data directories
init_postgres_data() {
    print_info "Initializing PostgreSQL data directories..."
    
    for shard_port in 5432 5433 5434; do
        data_dir="data/postgres/shard_${shard_port}"
        if [ ! -f "${data_dir}/PG_VERSION" ]; then
            print_info "Initializing data directory for shard on port ${shard_port}..."
            docker run --rm \
                -v "$(pwd)/data/postgres/shard_${shard_port}:/data" \
                alpine sh -c "apk add --no-cache postgresql-client && initdb -D /data --locale=C.UTF-8"
        else
            print_info "Data directory for shard on port ${shard_port} already initialized."
        fi
    done
}

# Create and set up scripts directory
create_scripts() {
    print_info "Creating scripts directory with essential utilities..."
    
    # Create a script to check database status
    cat > scripts/check_db_status.sh << 'EOF'
#!/bin/bash

# Script to check the status of all shard databases
set -euo pipefail

for shard_port in 5432 5433 5434; do
    echo "Checking shard database on port ${shard_port}..."
    docker exec shardsql_postgres_${shard_port} pg_isready -U postgres -p ${shard_port} && \
        echo "✓ Shard ${shard_port} is running" || \
        echo "✗ Shard ${shard_port} is not responding"
done
EOF

    # Create a script to view logs
    cat > scripts/view_logs.sh << 'EOF'
#!/bin/bash

# Script to view combined logs from all services

tail -f logs/postgres_5432.log logs/postgres_5433.log logs/postgres_5434.log
EOF

    chmod +x scripts/check_db_status.sh scripts/view_logs.sh scripts/init_shard_*.sql
    print_info "Scripts created and made executable."
}

# Create environment configuration file
create_env_config() {
    print_info "Creating environment configuration..."
    
    cat > configs/.env << EOF
# Shardsql Environment Configuration

# Database Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=shardsql_shard

# Shard Configuration
SHARD_1_PORT=5432
SHARD_2_PORT=5433
SHARD_3_PORT=5434

# Docker Configuration
DOCKER_NETWORK=shardsql_network

# Log Configuration
LOG_DIR=logs
EOF

    print_info "Environment configuration created."
}

# Initialize project with basic SQL scripts
init_sql_scripts() {
    print_info "Creating SQL initialization scripts..."
    
    # Create a basic initialization script for each shard
    for shard_port in 5432 5433 5434; do
        cat > scripts/init_shard_${shard_port}.sql << EOF
-- Initialization script for Shard ${shard_port}
-- This script creates the basic database structure for shard ${shard_port}

-- Connect to PostgreSQL as postgres user
\c postgres

-- Drop existing database if it exists (for clean initialization)
DROP DATABASE IF EXISTS shardsql_shard_${shard_port};

-- Create the shard database
CREATE DATABASE shardsql_shard_${shard_port};

-- Connect to the new database
\c shardsql_shard_${shard_port}

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
VALUES (${shard_port}, 'Shard Database Port ${shard_port}');

-- Add a comment to the database
COMMENT ON DATABASE shardsql_shard_${shard_port} IS 'Sharded database instance for Shard ${shard_port}';

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${POSTGRES_USER};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${POSTGRES_USER};
EOF
    done
    
    print_info "SQL initialization scripts created."
}

# Main function to run all initialization steps
main() {
    print_info "Starting shardsql environment initialization..."
    
    create_directory_structure
    init_postgres_data
    create_scripts
    create_env_config
    init_sql_scripts
    
    print_info "Initialization completed successfully!"
    print_info "Next steps:"
    print_info "1. Review the created directory structure"
    print_info "2. Update your application configuration to use the shard ports"
    print_info "3. Run ./docker-compose.yml to start the database instances"
    print_info "4. Use ./scripts/check_db_status.sh to verify databases are running"
    print_info "5. Use docker exec shardsql_postgres_<port> psql -U postgres -p <port> -f scripts/init_shard_<port>.sql to initialize each shard"
}

# Run main function
main