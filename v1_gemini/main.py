# main.py
#
# V7 of the scaffold for the MarketMinds AI agent.
#
# Key Upgrades in this version:
# - ARCHITECTURAL SHIFT (Context-First Pattern): To finally bypass the persistent
#   Pydantic validation error, we have shifted our approach. Instead of giving agents
#   tools, we now execute the tools first in our code and pass their string output
#   to the agents as 'context'. This avoids the broken tool validation logic entirely.
#
# How to run this application:
# 1. Make sure your llama.cpp server is running.
# 2. Install necessary packages from requirements.txt
# 3. Run the FastAPI server from your terminal:
#    uvicorn main:app --reload

import os
import uuid
import requests
import json
import sqlite3
import logging
from pathlib import Path
from typing import Dict, Any, List, Type

from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel, Field
from faker import Faker

from crewai import Agent, Task, Crew, Process
# We no longer need to import tool-related classes from LangChain here
from langchain.llms.base import LLM

# --- LOGGING SETUP ---
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("marketminds.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# --- CONFIGURATION & INITIALIZATION ---
LLAMA_CPP_SERVER_URL = "http://localhost:8080/completion"
DB_FILE = "jobs.db"
fake = Faker()


# --- DATABASE SETUP ---
def init_db():
    db_path = Path(DB_FILE)
    if not db_path.exists():
        logger.info(f"Database file not found. Creating new one at {DB_FILE}...")
        try:
            conn = sqlite3.connect(DB_FILE)
            cursor = conn.cursor()
            cursor.execute("""
                           CREATE TABLE jobs
                           (
                               id         TEXT PRIMARY KEY,
                               ticker     TEXT NOT NULL,
                               status     TEXT NOT NULL,
                               result     TEXT,
                               created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                           )
                           """)
            conn.commit()
            conn.close()
            logger.info("Database initialized successfully.")
        except sqlite3.Error as e:
            logger.error(f"Database error during initialization: {e}", exc_info=True)
            raise e


def get_db_connection():
    conn = sqlite3.connect(DB_FILE, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn


# --- CUSTOM LLM WRAPPER for LLAMA.CPP ---
class LlamaCppLLM(LLM):
    @property
    def _llm_type(self) -> str:
        return "custom_llama_cpp"

    def _call(self, prompt: str, stop: List[str] = None, **kwargs: Any) -> str:
        logger.info("LlamaCppLLM: Calling local LLM...")
        templated_prompt = f"### Instruction:\n{prompt}\n\n### Response:"
        stop_sequences = ["\n### Instruction:", "\n### Response:", "User:"]
        if stop: stop_sequences.extend(stop)

        payload = {"prompt": templated_prompt, "n_predict": 1024, "temperature": 0.2, "stop": stop_sequences}
        headers = {"Content-Type": "application/json"}

        try:
            logger.debug(f"Sending request to LLM server at {LLAMA_CPP_SERVER_URL}")
            response = requests.post(LLAMA_CPP_SERVER_URL, headers=headers, json=payload, timeout=300)
            response.raise_for_status()
            logger.info("LlamaCppLLM: Successfully received response from LLM.")
            return response.json().get("content", "")
        except requests.exceptions.RequestException as e:
            logger.error(f"LlamaCppLLM: Error connecting to LLM server: {e}", exc_info=True)
            return f"Error: Could not get a response from the LLM server. Details: {e}"
        except Exception as e:
            logger.error(f"LlamaCppLLM: An unexpected error occurred during LLM call: {e}", exc_info=True)
            return f"Error: An unexpected error occurred. Details: {e}"

    @property
    def _identifying_params(self) -> Dict[str, Any]:
        return {"server_url": LLAMA_CPP_SERVER_URL}


local_llm = LlamaCppLLM()


# --- TOOL FUNCTIONS (Plain Python) ---

def web_search_tool_func(query: str) -> str:
    """Simulates searching the web for a given query to find articles and sentiment."""
    logger.info(f"TOOL CALL: WebSearchTool with query: '{query}'")
    return (
        f"Search results for '{query}':\n- Article 1: {fake.bs().title()} - {fake.paragraph(nb_sentences=3)}\n- Article 2: Market sentiment leans positive as {fake.company()} announces record profits.\n- Article 3: Analysts express concern over {fake.word()}-related supply chain disruptions.")


def financial_data_tool_func(ticker: str) -> str:
    """Simulates fetching financial data for a stock ticker."""
    logger.info(f"TOOL CALL: FinancialDataTool with ticker: '{ticker}'")
    return (
        f"Financial data for {ticker}:\n- Current Price: ${fake.pydecimal(left_digits=3, right_digits=2, positive=True)}\n- 52-Week High: ${fake.pydecimal(left_digits=3, right_digits=2, positive=True) + 50}\n- 52-Week Low: ${fake.pydecimal(left_digits=3, right_digits=2, positive=True)}\n- Analyst Rating: {fake.random_element(elements=('Strong Buy', 'Buy', 'Hold', 'Sell'))}\n- P/E Ratio: {fake.pyfloat(positive=True, min_value=10, max_value=40, right_digits=2)}")


# --- HIERARCHICAL CREW DEFINITION ---

# The agents are now "tool-less". They only work with text context.
researcher = Agent(role='Senior Financial Analyst',
                   goal='Analyze the provided market data and news to extract key insights.',
                   backstory="You are a meticulous financial analyst...", verbose=True,
                   llm=local_llm)  # tools=[] is the default
writer = Agent(role='Expert Financial Report Writer',
               goal='Synthesize complex financial information into a clear, concise, and actionable report.',
               backstory="You are a skilled writer...", verbose=True, llm=local_llm)
fact_checker = Agent(role='Meticulous Fact Checker',
                     goal='Verify the accuracy of the financial report against the source data provided.',
                     backstory="You are a detail-oriented editor with an eagle eye...", verbose=True, llm=local_llm)

# --- FASTAPI APPLICATION ---
app = FastAPI(title="MarketMinds AI Agent - V7",
              description="An API to trigger and monitor a hierarchical financial research agent with persistent state and logging.")


@app.on_event("startup")
async def startup_event():
    logger.info("Application startup...")
    init_db()
    logger.info("Application startup complete.")


def run_crew_in_background(job_id: str, ticker: str):
    logger.info(f"BACKGROUND_TASK[{job_id}]: Starting for ticker '{ticker}'.")
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        logger.info(f"BACKGROUND_TASK[{job_id}]: Updating job status to RUNNING in DB.")
        cursor.execute("UPDATE jobs SET status = ? WHERE id = ?", ("RUNNING", job_id))
        conn.commit()

        # --- CONTEXT-FIRST EXECUTION ---
        logger.info(f"BACKGROUND_TASK[{job_id}]: Executing tools to gather context...")
        news_context = web_search_tool_func(query=f"Latest news for {ticker}")
        financial_context = financial_data_tool_func(ticker=ticker)
        full_context = f"--- LATEST NEWS ---\n{news_context}\n\n--- FINANCIAL DATA ---\n{financial_context}"
        logger.info(f"BACKGROUND_TASK[{job_id}]: Context gathered successfully.")

        # Define tasks with the gathered context
        research_task = Task(
            description="Analyze the provided context containing news and financial data. Extract key findings, market sentiment, and potential risks.",
            agent=researcher,
            expected_output=f"A summary of key insights from the data for {ticker}."
        )
        write_task = Task(
            description="Using the analysis from the researcher, synthesize the information into a structured financial brief with sections: 'Recent News', 'Financial Snapshot', 'Outlook & Risks'.",
            agent=writer,
            expected_output=f"A formatted financial brief for {ticker}.",
            context=[research_task]
        )
        fact_check_task = Task(
            description="Review the generated brief. The initial raw data is also provided in the context for your reference. Ensure the report is accurate and well-supported.",
            agent=fact_checker,
            expected_output=f"A final, fact-checked, and polished financial brief for {ticker}.",
            context=[write_task]
        )

        tasks = [research_task, write_task, fact_check_task]

        financial_crew = Crew(
            agents=[researcher, writer, fact_checker],
            tasks=tasks,
            process=Process.sequential,  # Sequential is simpler and sufficient here
            # Pass the full context to the crew. It will be available to all tasks.
            context={"full_research_data": full_context}
        )

        logger.info(f"BACKGROUND_TASK[{job_id}]: Crew created. Kicking off job...")
        result = financial_crew.kickoff()
        logger.info(f"BACKGROUND_TASK[{job_id}]: Crew kickoff complete.")

        cursor.execute("UPDATE jobs SET status = ?, result = ? WHERE id = ?", ("COMPLETED", result, job_id))
        logger.info(f"BACKGROUND_TASK[{job_id}]: Job status updated to COMPLETED in DB.")
    except Exception as e:
        logger.error(f"BACKGROUND_TASK[{job_id}]: An error occurred during crew execution.", exc_info=True)
        cursor.execute("UPDATE jobs SET status = ?, result = ? WHERE id = ?", ("FAILED", str(e), job_id))
    finally:
        conn.commit()
        conn.close()
        logger.info(f"BACKGROUND_TASK[{job_id}]: Finished.")


class ResearchRequest(BaseModel):
    ticker: str


@app.post("/research", status_code=202)
async def start_research(request: ResearchRequest, background_tasks: BackgroundTasks):
    logger.info(f"API_POST[/research]: Received request for ticker: '{request.ticker}'")
    job_id = str(uuid.uuid4())
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT INTO jobs (id, ticker, status) VALUES (?, ?, ?)", (job_id, request.ticker, "PENDING"))
    conn.commit()
    conn.close()
    logger.info(f"API_POST[/research]: Created job {job_id} and added to background tasks.")
    background_tasks.add_task(run_crew_in_background, job_id, request.ticker)
    return {"message": "Research task accepted.", "job_id": job_id}


@app.get("/research/status/{job_id}")
async def get_status(job_id: str):
    logger.info(f"API_GET[/research/status]: Checking status for job_id: {job_id}")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT id, status FROM jobs WHERE id = ?", (job_id,))
    job = cursor.fetchone()
    conn.close()
    if not job:
        logger.warning(f"API_GET[/research/status]: Job not found for job_id: {job_id}")
        raise HTTPException(status_code=404, detail="Job not found")
    return dict(job)


@app.get("/research/result/{job_id}")
async def get_result(job_id: str):
    logger.info(f"API_GET[/research/result]: Fetching result for job_id: {job_id}")
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM jobs WHERE id = ?", (job_id,))
    job = cursor.fetchone()
    conn.close()
    if not job:
        logger.warning(f"API_GET[/research/result]: Job not found for job_id: {job_id}")
        raise HTTPException(status_code=404, detail="Job not found")
    if job["status"] != "COMPLETED":
        logger.warning(
            f"API_GET[/research/result]: Attempted to fetch result for incomplete job {job_id}. Status: {job['status']}")
        raise HTTPException(status_code=400, detail=f"Job is not complete. Current status: {job['status']}")
    logger.info(f"API_GET[/research/result]: Successfully retrieved result for job {job_id}.")
    return dict(job)

