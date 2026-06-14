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
- `Dockerfile` — container image (model baked in, listens on 8080)
- `.github/workflows/release_container.yml` — builds + pushes the image to GHCR
- `embedding.service` — systemd unit template
- `deploy.sh` — one-shot installer for a fresh Linux server

## Container release (like the other MapleKiosk apps)

Run the **Release Container** workflow (Actions tab → *Release Container* → Run workflow,
enter a version like `1.0.0`). It builds the image and pushes:

- `ghcr.io/ericngo1972/embedding:<version>`
- `ghcr.io/ericngo1972/embedding:latest`

The provisioner maps/health-checks **internal port 8080**, and `EMBED_API_KEY` must be
supplied at `docker run` time. Catalog row: `ImageRepository=ghcr.io/ericngo1972/embedding`,
`InternalPort=8080`.

Run it manually:

```bash
docker run -d -p 8080:8080 -e EMBED_API_KEY=your-secret-key \
  --memory=3g ghcr.io/ericngo1972/embedding:latest
```

## Resource requirements

This service is **heavier than the .NET MapleKiosk apps** — size hosts accordingly.

| Resource | Need | Notes |
|---|---|---|
| **RAM** | ~1.7–2.2 GB steady-state; **set a 3 GB limit** | Starts in ~1.5 GB; a tight limit risks OOM under concurrent / large-batch requests. |
| **Disk (image)** | ~2.5–3 GB uncompressed | `python:3.12-slim` + torch-CPU + deps + the baked ~1.1 GB model. Ensure free space for the pull. |
| **CPU / GPU** | CPU-only | Uses the torch-CPU build — no GPU / VRAM required. |

What changes the numbers:

- **Batch size matters most.** A single short string is cheap; sending hundreds of long
  texts in one `input` array spikes activation memory — lean toward 4 GB if callers batch heavily.
- **`--workers`.** Currently `--workers 1`. Each extra uvicorn worker loads its **own** full
  copy of the model (~1.5 GB each) — don't raise it without multiplying RAM. On CPU, prefer
  batching over more workers for throughput.

Provisioner catalog: register with a **3 GB memory limit**, `InternalPort=8080`.

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
