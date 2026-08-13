from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel
from typing import Any, Dict
import asyncio
from coordinator import process_query

app = FastAPI(title="Distributed Data Warehouse API")

class QueryRequest(BaseModel):
    natural_language_query: str

async def get_coordinator() -> Dict[str, Any]:
    # Return the actual coordinator as a callable
    return {"process_query": process_query}

@app.post("/query")
async def query_endpoint(
    request: QueryRequest,
    coordinator: Dict[str, Any] = Depends(get_coordinator)
) -> Dict[str, Any]:
    # Use the actual coordinator to process the query
    result = await coordinator["process_query"](request.natural_language_query)
    return result