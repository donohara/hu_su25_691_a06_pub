# =============================================================================
# test_client.py - Example usage of the REST API
# =============================================================================

import requests
import time
import json


class ResearchMateClient:
    """Simple client for testing ResearchMate API"""

    def __init__(self, base_url="http://localhost:8000"):
        self.base_url = base_url

    def start_research(self, query: str, research_focus: str = None):
        """Start a research job"""
        payload = {"query": query}
        if research_focus:
            payload["research_focus"] = research_focus

        response = requests.post(f"{self.base_url}/research/query", json=payload)
        return response.json()

    def check_status(self, job_id: str):
        """Check job status"""
        response = requests.get(f"{self.base_url}/research/status/{job_id}")
        return response.json()

    def get_results(self, job_id: str):
        """Get research results"""
        response = requests.get(f"{self.base_url}/research/results/{job_id}")
        return response.json()

    def wait_for_completion(self, job_id: str, timeout: int = 300):
        """Wait for job to complete"""
        start_time = time.time()

        while time.time() - start_time < timeout:
            status = self.check_status(job_id)
            print(f"Status: {status['status']}")

            if status["status"] == "completed":
                return self.get_results(job_id)
            elif status["status"] == "failed":
                raise Exception(f"Job failed: {status.get('error', 'Unknown error')}")

            time.sleep(5)

        raise TimeoutError("Job did not complete within timeout")