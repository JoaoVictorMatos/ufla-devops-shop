# Atividade 4 -- Containerizar a aplicacao

Autor: Joao Victor Matos (@JoaoVictorMatos)

## 1. Antes e depois

Medido na minha maquina (amd64, Docker 29.7.2). Esta versao do Docker usa o
*image store* do containerd, entao `docker images` mostra duas colunas e
`docker image inspect --format '{{.Size}}'` devolve o tamanho **comprimido**.
Por isso informo tambem a soma das camadas (tamanho descomprimido, o numero
comparavel com `docs/aplicacao.md`):

```
$ docker images ufla-shop
IMAGE           ID             DISK USAGE   CONTENT SIZE
ufla-shop:1.0   49bf682993c1   139MB        32.6MB
ufla-shop:v1    e5de2a840f1b   274MB        71MB

$ docker history --human=false --format '{{.Size}}' <imagem> | paste -sd+ | bc
ufla-shop:v1   ->  203M   (primeira versao que funcionou)
ufla-shop:1.0  ->  107M   (versao final)
```

| Versao | Base | Camadas somadas | `.Size` (comprimido) | `DISK USAGE` |
|--------|------|-----------------|----------------------|--------------|
| `v1` (antes) | `python:3.12-slim`, estagio unico | 203 MB | 72 MB | 274 MB |
| `1.0` (final) | `python:3.12-alpine`, multi-stage | **107 MB** | 33 MB | 139 MB |

Em qualquer das medidas a imagem final fica abaixo de 150 MB.

A `v1` era o Dockerfile mais simples possivel (`FROM python:3.12-slim`,
`pip install`, `COPY`, `CMD uvicorn ...` na forma shell). Ele funciona, mas ainda
nao atende os requisitos de multi-stage, usuario nao-root, `HEALTHCHECK` e
`CMD` na forma exec.

## 2. O que mudou e quanto cada mudanca economizou

Pelo `docker history`, a `v1` tem ~134 MB de base slim + 68,5 MB de dependencias.
A versao final tem ~63 MB de base alpine + 43,9 MB de dependencias.

| Mudanca | Economia aproximada | Por que |
|---------|---------------------|---------|
| Base `python:3.12-slim` -> `python:3.12-alpine` | ~71 MB (134 -> 63 MB) | Alpine usa musl e busybox em vez de glibc e utilitarios Debian. Todas as dependencias tem *wheels* para musl, entao nada precisa ser compilado. |
| `pip install --no-cache-dir --prefix=/install` no estagio *builder*, copiado com `COPY --from=builder` | ~25 MB (68,5 -> 43,9 MB) | O cache do pip e os `.pyc` gerados na instalacao ficam no estagio *builder*, que e descartado. A imagem final recebe so os pacotes instalados. |
| `.dockerignore` (`.git`, `.venv`, `tests`, `*.db`, `.env`, `dados/`, `docs/`...) e `COPY` apenas de `app/` e `static/` | nao medida (a `v1` ja copiava so `app/` e `static/`) | Protege contra um `COPY . .` futuro: o repositorio local tem `dados/access.log` (87 MB) e pode ter `.venv`, `.git` e `.env`, que iriam para a imagem. |
| `PYTHONDONTWRITEBYTECODE=1` | nao medida | O Python nao grava `__pycache__` em tempo de execucao, mantendo o sistema de arquivos do container limpo. |

Mudancas que nao mexem em tamanho, mas sao requisitos:

- **Nao-root**: `adduser -D -h /app app` + `USER app`. O home do usuario e o
  `WORKDIR`, entao o SQLite do modo autonomo consegue gravar `loja.db` sem
  `Permission denied`.
- **`CMD` na forma exec**: `["uvicorn", "app:api", ...]`. O uvicorn e o PID 1 e
  recebe o `SIGTERM` direto; na forma shell o PID 1 seria o `sh` e cada
  `docker stop` esperaria 10 s ate o `SIGKILL`.
- **`HEALTHCHECK` com o proprio Python** (`urllib.request`), porque o Alpine nao
  tem `curl`, apontando para `127.0.0.1:8000/health` (roda dentro do container).

## 3. Saida da verificacao

```
$ docker build -t ufla-shop:1.0 .
$ docker image inspect --format '{{.Size}}' ufla-shop:1.0 | numfmt --to=si
33M          # comprimido; descomprimido (soma das camadas): 107M

$ docker run -d --name loja -p 8000:8000 ufla-shop:1.0
$ docker run --rm ufla-shop:1.0 id -u
1000

$ docker run --rm ufla-shop:1.0 ls -a /app
.
..
app
static

$ sleep 10 && docker inspect --format '{{.State.Health.Status}}' loja
healthy

$ curl -s localhost:8000/health
{"status":"ok","versao":"1.0.0"}
$ curl -s localhost:8000/api/produtos | python3 -c "import sys,json; print(len(json.load(sys.stdin)), 'produtos')"
12 produtos

$ time docker stop loja
loja

real	0m0.366s
```

## 4. Por que o HEALTHCHECK consulta `/health` e nao `/ready`?

`/health` e *liveness*: so responde se o processo esta vivo e nunca toca em
banco ou cache, entao ele falha apenas quando reiniciar o container realmente
resolve. `/ready` devolve `503` quando uma dependencia esta fora, e usa-lo no
`HEALTHCHECK` faria um problema de banco ou Redis marcar como `unhealthy` um
container que esta perfeitamente saudavel -- reiniciar nao consertaria nada.
