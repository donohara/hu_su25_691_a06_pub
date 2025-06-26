from langchain.chains import SimpleSequentialChain
from langchain.prompts import PromptTemplate
from grant_fetcher import fetch_grants
import spacy
from local_llama_langchain import LocalLlamaLLM
from logging_config import setup_logger

logger = setup_logger("llm_chain")

# Load spaCy model for keyword extraction
nlp = spacy.load("en_core_web_sm")

# Instantiate local LLM
llm = LocalLlamaLLM()

def extract_keywords(text: str) -> list[str]:
    doc = nlp(text)
    keywords = list(set(ent.text for ent in doc.ents if
                        ent.label_ in {"ORG", "GPE", "PERSON", "NORP", "FAC", "EVENT", "WORK_OF_ART", "LAW", "LANGUAGE"}))
    logger.debug("spaCy extracted keywords", extra={"keywords": keywords})
    return keywords

def build_pipeline(query: str) -> str:
    logger.info("Starting build_pipeline", extra={"query": query})

    # Classification step (not reused, but demo of LangChain Prompt → LLM chain)
    classification_prompt = PromptTemplate.from_template("Classify this user query into domain + intent: {input}")
    classify_chain = classification_prompt | llm
    classification_result = classify_chain.invoke({"input": query})
    logger.info("Classification result", extra={"classification": classification_result})

    # Keyword extraction
    keywords = extract_keywords(query)

    # Grant matching (stubbed)
    grants = fetch_grants(keywords)
    logger.debug("Fetched grants", extra={"grants": grants})

    # Compose LLM input for summarization
    grant_text = "\n".join(f"- {g['title']} ({g['agency']}), deadline: {g['deadline']}" for g in grants)
    summary_input = f"""User query: {query}
Classification: {classification_result}
Extracted Keywords: {keywords}
Matching Grants:
{grant_text}

Summarize and rank the grants by relevance to the user query."""

    logger.info("Calling LLM for summarization", extra={"summary_input_preview": summary_input[:200]})
    summary = llm(summary_input)
    logger.info("Summary complete", extra={"summary_snippet": summary[:100]})

    return summary
