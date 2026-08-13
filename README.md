# 🗄️ ShardSQL: An Intelligent Distributed Database Router

Have you ever wanted to just *ask* your database a question in plain English and have it figure out where the data lives? That is exactly what ShardSQL does. 

This project is a lightweight, intelligent data warehouse coordinator. It takes a natural language question (like *"What were the total sales in the US?"*), uses Google's Gemini LLM to translate it into a valid PostgreSQL query, and then routes that query strictly to the correct database shard. 

Instead of doing full-cluster scans for every question, ShardSQL knows exactly which database node has the data you are looking for.

## ✨ How It Works Under the Hood

1. The Gateway: You send a plain-English question to the FastAPI `/query` endpoint.
2. The Brain: Gemini 3.6 Flash translates your question into a raw SQL string and determines which specific database shards (US, EU, or Global) hold the answers.
3. The Router: A custom Python coordinator uses `asyncpg` and `asyncio.gather` to fire the SQL query concurrently at the target shards. No synchronous blocking!
4. The Aggregator: The engine collects the rows from the distributed PostgreSQL databases, performs final math aggregations in Python (like summing totals), and hands you a clean JSON answer.

## 🚀 Getting Started

If you want to run this on your own machine, here is how to get the cluster up and running.

### 1. Prerequisites
You will need:
* **Python 3.10+**
* **Docker & Docker Compose** (to run the database shards)
* A **Google Gemini API Key**

### 2. Environment Setup
Create a `.env` file in the root of the project and add your API key:
```env
GEMINI_API_KEY=your_actual_key_here