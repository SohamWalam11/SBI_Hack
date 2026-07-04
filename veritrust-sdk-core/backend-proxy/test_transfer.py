import requests
import json
url = "http://localhost:8000/api/v1/query"
payload = {
    "session_id": "123",
    "query": "Transfer 500 rupees to Mom"
}
response = requests.post(url, json=payload)
print(json.dumps(response.json(), indent=2))
