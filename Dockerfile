# Runtime image for the MK Embedding Service (OpenAI-compatible text embeddings).
# Unlike the .NET MapleKiosk apps, this is a self-contained Python service with no sibling
# repo dependency, so the build context is the repo root and the image is built straight from
# source (see .github/workflows/release_container.yml).
FROM python:3.12-slim

WORKDIR /app

# Install deps. torch's +cpu build only lives on the PyTorch index, so install it from there
# first; the rest come from PyPI. (requirements.txt pins torch too, but it's already satisfied.)
COPY requirements.txt ./
RUN pip install --no-cache-dir torch==2.10.0+cpu --index-url https://download.pytorch.org/whl/cpu \
 && pip install --no-cache-dir -r requirements.txt

# Bake the embedding model into the image so containers start fast and work offline (no ~1GB
# Hugging Face download on first run, the way the bare-metal deployment on 192.168.2.5 does).
ENV HF_HOME=/models
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('paraphrase-multilingual-mpnet-base-v2')"

COPY app.py ./

# Listen on 8080 inside the container — the port the provisioner maps to and health-checks,
# matching the other MapleKiosk apps (e.g. MemberList).
EXPOSE 8080

# EMBED_API_KEY is injected by the provisioner at `docker run` time (every request needs it).
ENTRYPOINT ["python", "-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]
