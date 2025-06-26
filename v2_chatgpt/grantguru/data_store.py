store = {}

def get_status(job_id):
    return store.get(job_id, None)
