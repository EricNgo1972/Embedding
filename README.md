# MK Embedding Service

OpenAI-compatible text embedding web service (FastAPI + sentence-transformers).

| | |
|---|---|
| **Model** | `paraphrase-multilingual-mpnet-base-v2` (multilingual EN / FR / VI) |
| **Vector dim** | 768 |
| **Endpoint** | `POST /embeddings` (OpenAI `/v1/embeddings`-compatible, single + batch) |
| **Landing page** | `GET /` (status + usage docs) |
| **Auth** | header `X-API-Key`, value from env var `EMBED_API_KEY` |
| **Port** | 8000 |

## Files

- `app.py` — the service
- `requirements.txt` — pinned dependency versions (matches production)
- `embedding.service` — systemd unit template
- `deploy.sh` — one-shot installer for a fresh Linux server

## Production deployment

Running on `192.168.2.5` (host `phoebus`) at `/var/www/embedding-service/`,
as systemd unit `embedding.service` (user `eric`).

## Deploy on a new server

```bash
# copy this folder to the server, then:
EMBED_API_KEY="your-secret-key" ./deploy.sh
```

For a GPU host: `GPU=1 EMBED_API_KEY=... ./deploy.sh`

> First start downloads the model (~1 GB) from Hugging Face into
> `~/.cache/huggingface`, so the server needs internet on first run.
> For an offline box, copy `~/.cache/huggingface/` from an existing deployment.

## Run locally (dev)

```bash
python3 -m venv venv
./venv/bin/pip install torch==2.10.0+cpu --index-url https://download.pytorch.org/whl/cpu
./venv/bin/pip install -r requirements.txt
export EMBED_API_KEY="your-secret-key"
./venv/bin/python -m uvicorn app:app --host 0.0.0.0 --port 8000
```

## Test

```bash
curl -X POST http://localhost:8000/embeddings \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-secret-key" \
  -d '{"input": "Invoice total is 1200 CAD"}'
```
