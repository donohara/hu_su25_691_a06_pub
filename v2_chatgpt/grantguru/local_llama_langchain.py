# local_llama_langchain.py
from langchain.llms.base import LLM
from typing import Optional, List
import requests

class LocalLlamaLLM(LLM):
    endpoint: str = "http://localhost:8080/completion"
    max_tokens: int = 512
    temperature: float = 0.7
    stop: Optional[List[str]] = None

    @property
    def _llm_type(self) -> str:
        return "local-llama"

    def _call(self, prompt: str, stop: Optional[List[str]] = None) -> str:
        payload = {
            "prompt": prompt,
            "temperature": self.temperature,
            "max_tokens": self.max_tokens,
        }
        if self.stop:
            payload["stop"] = self.stop

        response = requests.post(self.endpoint, json=payload)
        response.raise_for_status()
        return response.json()["content"].strip()
