import requests

LLAMA_SERVER = "http://localhost:8080"

def call_llm(prompt: str) -> str:
    response = requests.post(f"{LLAMA_SERVER}/completion", json={
        "prompt": prompt,
        "max_tokens": 512,
        "stop": ["</s>"]
    })
    return response.json()["content"]
