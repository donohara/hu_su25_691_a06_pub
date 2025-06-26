from langchain.chat_models import ChatOpenAI
from langchain.chains import SimpleSequentialChain
from langchain.prompts import PromptTemplate
from grant_fetcher import fetch_grants
import spacy
from llama_client import call_llm

from logging_config import setup_logger
logger = setup_logger("llm_chain")

nlp = spacy.load("en_core_web_sm")

llm = ChatOpenAI(model_name="gpt-3.5-turbo", temperature=0)  # Placeholder for future LLM integration


def extract_keywords(text: str) -> list[str]:
    doc = nlp(text)
    return list(set(ent.text for ent in doc.ents if
                    ent.label_ in {"ORG", "GPE", "PERSON", "NORP", "FAC", "EVENT", "WORK_OF_ART", "LAW", "LANGUAGE"}))


def build_pipeline(query: str) -> str:
    logger.info("Starting build_pipeline", extra={"query": query})

    classification_prompt = PromptTemplate.from_template("Classify this user query into domain + intent: {input}")
    classify_chain = classification_prompt | llm

    logger.debug("Running spaCy keyword extraction")
    keywords = extract_keywords(query)
    logger.debug("Extracted keywords", extra={"keywords": keywords})

    grants = fetch_grants(keywords)
    logger.debug("Fetched grants", extra={"grants": grants})

    grant_text = "\n".join(f"- {g['title']} ({g['agency']}), deadline: {g['deadline']}" for g in grants)

    summary_input = f"""User is asking: {query}
Extracted Keywords: {keywords}
Here are the grants:\n{grant_text}
Summarize and rank the grants by relevance to query."""

    logger.info("Calling LLM for summarization")
    summary = call_llm(summary_input)

    logger.info("Summary complete", extra={"summary_snippet": summary[:100]})
    return summary
