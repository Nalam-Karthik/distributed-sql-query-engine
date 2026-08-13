import os
import json
import asyncio
import google.generativeai as genai
from dotenv import load_dotenv
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text

# ---------------------------------------------------------
# 1. Environment & LLM Configuration
# ---------------------------------------------------------
load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

SYSTEM_PROMPT = """
You are a PostgreSQL routing expert for a distributed database system.
Your job is to translate natural language into SQL and determine which database shards need to be queried.

DATABASE SCHEMA (Table Name: sales)
- id (Integer, Primary Key)
- region (String - 'US', 'EU', 'AS', 'AF', 'SA', 'OC')
- amount (Float)
- date (Date)

SHARDING RULES:
- Shard 5432 contains ONLY region = 'US'
- Shard 5433 contains ONLY region = 'EU'
- Shard 5434 contains ALL OTHER regions ('AS', 'AF', 'SA', 'OC')

OUTPUT FORMAT:
You must respond with ONLY a valid JSON object. No markdown formatting, no explanations.
The JSON must perfectly match this structure:
{
    "sql": "SELECT SUM(amount) as total FROM sales WHERE region = 'US';",
    "target_shards": [5432]
}

If a query asks for global data or data spanning multiple regions, include all relevant shards in the target_shards list, e.g., [5432, 5433, 5434].
"""

# Reverting to the highly stable flash model
model = genai.GenerativeModel(
    model_name="gemini-3.6-flash", 
    system_instruction=SYSTEM_PROMPT,
    generation_config={"response_mime_type": "application/json"}
)

# ---------------------------------------------------------
# 2. Asynchronous Database Connection Manager
# ---------------------------------------------------------
DB_URLS = {
    5432: "postgresql+asyncpg://postgres:postgres@127.0.0.1:5432/shardsql_shard_5432",
    5433: "postgresql+asyncpg://postgres:postgres@127.0.0.1:5433/shardsql_shard_5433",
    5434: "postgresql+asyncpg://postgres:postgres@127.0.0.1:5434/shardsql_shard_5434"
}

engines = {port: create_async_engine(url, echo=False) for port, url in DB_URLS.items()}
sessions = {port: sessionmaker(engine, class_=AsyncSession, expire_on_commit=False) for port, engine in engines.items()}

# ---------------------------------------------------------
# 3. Core Coordinator Logic
# ---------------------------------------------------------
async def fetch_from_shard(port: int, sql_query: str) -> dict:
    """Executes the SQL query against a specific shard and returns the rows."""
    # We wrap the ENTIRE context manager in a try/except to catch timeout rollbacks
    try:
        Session = sessions[port]
        async with Session() as session:
            result = await session.execute(text(sql_query))
            rows = [dict(row._mapping) for row in result]
            return {"shard": port, "data": rows, "status": "success"}
    except Exception as e:
        return {"shard": port, "data": [], "status": "error", "message": str(e)}

async def process_query(natural_language: str) -> dict:
    """The main orchestration function."""
    try:
        # We now use the ASYNC method so FastAPI doesn't freeze
        response = await model.generate_content_async(natural_language)
        llm_payload = json.loads(response.text)
        sql_query = llm_payload.get("sql")
        target_shards = llm_payload.get("target_shards", [])
        
        # LLM Safeguard: Force integers into a list
        if isinstance(target_shards, int):
            target_shards = [target_shards]
            
    except Exception as e:
        return {"error": "LLM Translation Failed", "details": str(e)}

    if not sql_query or not target_shards:
        return {"error": "Invalid LLM Response", "payload": llm_payload}

    # Scatter-Gather Routing
    tasks = [fetch_from_shard(port, sql_query) for port in target_shards if port in engines]
    
    if not tasks:
        return {"error": "No valid shards targeted.", "target_shards": target_shards}

    shard_results = await asyncio.gather(*tasks)

    # Aggregation
    unified_data = []
    for res in shard_results:
        if res["status"] == "success":
            unified_data.extend(res["data"])

    final_aggregated_value = None
    is_aggregation = any(keyword in sql_query.upper() for keyword in ["SUM(", "COUNT(", "AVG(", "MAX(", "MIN("])
    
    if is_aggregation and unified_data:
        values_to_aggregate = []
        for row in unified_data:
            vals = list(row.values())
            # Ensure we don't hit an IndexError on empty mappings
            if vals and vals[0] is not None:
                values_to_aggregate.append(vals[0])
                
        if values_to_aggregate:
            final_aggregated_value = sum(values_to_aggregate)

    return {
        "original_query": natural_language,
        "generated_sql": sql_query,
        "shards_queried": target_shards,
        "raw_shard_results": shard_results,
        "aggregated_result": final_aggregated_value if is_aggregation else unified_data
    }