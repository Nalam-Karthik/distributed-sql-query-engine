#!/usr/bin/env python3
"""
ingest.py - Generate and insert synthetic sales data across sharded PostgreSQL databases
Uses SQLAlchemy ORM to interact with Shardsql database shards with proper transaction routing
"""
import os
import sys
import random
from faker import Faker
from datetime import datetime
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError

# Import your SQLAlchemy model
# This should be the same model that was migrated via alembic
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from models import Sales

def generate_random_sales_data(num_records: int = 10000):
    """
    Generate synthetic sales data with proper sharding routing.
    
    Sharding rules:
    - US regions → Shard 1 (5432)
    - EU regions → Shard 2 (5433) 
    - All other regions → Shard 3 (5434)
    """
    fake = Faker()
    shard_buckets = {5432: [], 5433: [], 5434: []}
    
    print(f"Generating {num_records} synthetic sales records...")
    
    for _ in range(num_records):
        # Random region from the 6 supported region codes
        region_code = random.choice(['US', 'EU', 'AS', 'AF', 'SA', 'OC'])
        region_name = region_code
        
        # Random transaction amount between $10-$1,000
        amount = round(random.uniform(10.00, 1000.00), 2)
        
        # Random date within the last year
        date = fake.date_between(start_date='-1y', end_date='today')
        
        # Create Sales instance
        sale = Sales(
            region=region_name,
            amount=amount,
            date=date
        )
        
        # Route to appropriate shard based on region
        if region_code == 'US':
            shard_buckets[5432].append(sale)
        elif region_code == 'EU':
            shard_buckets[5433].append(sale)
        else:
            shard_buckets[5434].append(sale)
    
    return shard_buckets

def bulk_insert_shard(shard_port: int, bucket_name: str, records: list):
    """
    Bulk insert records into a specific shard database connection.
    
    Args:
        shard_port: Database port number indicating the shard
        bucket_name: Name for display purposes
        records: List of Sales objects to insert
    """
    if not records:
        print(f"⚠️  Shard {shard_port} ({bucket_name}): No records to insert")
        return
        
    # Construct PostgreSQL connection URL
    db_name = f"shardsql_shard_{shard_port}"
    url = f"postgresql://postgres:postgres@127.0.0.1:{shard_port}/{db_name}"
    
    try:
        # Create engine and session for this specific shard
        engine = create_engine(url)
        Session = sessionmaker(bind=engine)
        
        with Session() as session:
            try:
                # Perform bulk insert operation
                session.bulk_save_objects(records)
                session.commit()
                print(f"✅ Shard {shard_port} ({bucket_name}): Inserted {len(records)} records successfully")
            except SQLAlchemyError as e:
                session.rollback()
                print(f"❌ Shard {shard_port} ({bucket_name}): Database error - {str(e)}")
                raise
    except SQLAlchemyError as e:
        print(f"❌ Shard {shard_port} ({bucket_name}): Connection error - {str(e)}")

def main():
    print("=" * 60)
    print("SHARDED SALES DATA INGESTION PROCESS")
    print("=" * 60)
    
    # Generate data and distribute across shards
    buckets = generate_random_sales_data(10000)
    
    print("\n" + "-" * 50)
    print("BULK INSERTION STARTED")
    print("-" * 50)
    
    # Insert into each shard
    for port, bucket_name in [(5432, "US"), (5433, "EU"), (5434, "Other")]:
        if buckets[port]:  # Only insert if there are records
            bulk_insert_shard(port, bucket_name, buckets[port])
    
    print("\n" + "=" * 60)
    print("INGESTION COMPLETE")
    print("=" * 60)

if __name__ == "__main__":
    main()