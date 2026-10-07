# syntax=docker/dockerfile:1

# ---- Estagio 1: instala as dependencias (ferramentas de build ficam aqui) ----
FROM python:3.12-alpine AS builder
WORKDIR /build
COPY requirements.txt .
# --prefix isola so o que foi instalado; --no-cache-dir evita o cache do pip
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Estagio 2: imagem final, so o necessario para executar ----
FROM python:3.12-alpine
# Usuario sem privilegios; o home e o WORKDIR, entao o SQLite pode escrever la
RUN adduser -D -h /app app
WORKDIR /app
COPY --from=builder /install /usr/local
COPY --chown=app:app app/ app/
COPY --chown=app:app static/ static/

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
USER app
EXPOSE 8000

# Roda dentro do container: o endereco e 127.0.0.1, e o proprio Python faz a
# requisicao (alpine nao tem curl). /health e liveness: nao depende de banco.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"]

# Forma exec: uvicorn vira o PID 1 e recebe o SIGTERM do docker stop
CMD ["uvicorn", "app:api", "--host", "0.0.0.0", "--port", "8000"]
