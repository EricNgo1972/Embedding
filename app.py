from fastapi import FastAPI, Header, HTTPException, Depends
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import List, Union
from sentence_transformers import SentenceTransformer
import torch
import os

# =========================
# App Setup
# =========================

app = FastAPI(title="OpenAI-Compatible Embedding Service")

# =========================
# Security
# =========================

API_KEY = os.getenv("EMBED_API_KEY")

def verify_api_key(x_api_key: str = Header(None)):
    if API_KEY is None:
        raise HTTPException(status_code=500, detail="API key not configured")

    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

# =========================
# Load Model Once
# =========================

MODEL_NAME = "paraphrase-multilingual-mpnet-base-v2"

print("Loading embedding model...")

device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Using device: {device}")

model = SentenceTransformer(MODEL_NAME, device=device)

print("Model loaded successfully.")

# =========================
# Request Models (OpenAI-style)
# =========================

class EmbeddingRequest(BaseModel):
    input: Union[str, List[str]]
    model: str | None = None  # accepted for compatibility, ignored internally

# =========================
# Routes
# =========================

@app.get("/", response_class=HTMLResponse)
def root():
    return f"""
<!DOCTYPE html>
<html>
<head>
    <title>Embedding Service</title>
    <style>
        body {{
            font-family: system-ui, -apple-system, sans-serif;
            background: #0f172a;
            color: #e5e7eb;
            padding: 24px;
            max-width: 900px;
            margin: auto;
        }}
        code {{
            background: #020617;
            padding: 10px;
            border-radius: 6px;
            display: block;
            white-space: pre-wrap;
            margin: 10px 0;
        }}
        h1, h2 {{
            color: #38bdf8;
        }}
        ul {{
            margin-left: 20px;
        }}
        .warn {{
            background: #1e293b;
            border-left: 4px solid #f97316;
            padding: 12px;
            margin: 16px 0;
        }}
    </style>
</head>
<body>
    <h1>OpenAI-Compatible Embedding Service</h1>

    <p><b>Status:</b> Running</p>
    <p><b>Model:</b> {MODEL_NAME}</p>
    <p><b>Device:</b> {device}</p>

    <div class="warn">
        <b>Authentication Required</b><br/>
        All embedding requests <b>must</b> include the HTTP header:
        <code>X-API-Key: &lt;your-api-key&gt;</code>
    </div>

    <h2>Endpoint</h2>
    <code>POST /embeddings</code>

    <h2>Required Headers</h2>
    <code>
Content-Type: application/json
X-API-Key: your-secret-key
    </code>

    <h2>Request (single input)</h2>
    <code>
{{
  "input": "Invoice total is 1200 CAD"
}}
    </code>

    <h2>Request (batch)</h2>
    <code>
{{
  "input": [
    "Invoice total is 1200 CAD",
    "Receipt from Starbucks"
  ]
}}
    </code>

    <h2>Response</h2>
    <code>
{{
  "object": "list",
  "data": [
    {{
      "object": "embedding",
      "embedding": [0.0123, -0.4567, ...],
      "index": 0
    }}
  ],
  "model": "{MODEL_NAME}"
}}
    </code>

    <h2>Notes</h2>
    <ul>
        <li>Compatible with OpenAI <code>/v1/embeddings</code></li>
        <li>Multilingual (EN / FR / VI)</li>
        <li>Batch input supported</li>
        <li>Embedding dimension: 768</li>
        <li>Cosine similarity recommended</li>
    </ul>
</body>
</html>
"""

@app.post("/embeddings")
def embeddings(req: EmbeddingRequest, _: None = Depends(verify_api_key)):
    texts = req.input

    if isinstance(texts, str):
        texts = [texts]

    embeddings = model.encode(
        texts,
        convert_to_numpy=True,
        normalize_embeddings=False
    )

    vectors = embeddings.tolist()

    return {
        "object": "list",
        "data": [
            {
                "object": "embedding",
                "embedding": vector,
                "index": i
            }
            for i, vector in enumerate(vectors)
        ],
        "model": MODEL_NAME
    }