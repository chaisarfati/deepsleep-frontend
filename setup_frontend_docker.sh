#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"

cd "$ROOT"

if [[ ! -f "index.html" || ! -f "app.js" || ! -d "js" || ! -d "css" ]]; then
  echo "Erreur: lance ce script depuis la racine du frontend DeepSleep."
  exit 1
fi

mkdir -p .github/workflows

echo "==> Backup du fichier client API"
if [[ -f "js/api/client.js" ]]; then
  cp "js/api/client.js" "js/api/client.js.bak.$(date +%Y%m%d%H%M%S)"
else
  echo "Erreur: js/api/client.js introuvable"
  exit 1
fi

echo "==> Patch de js/api/client.js"
python3 - <<'PY'
from pathlib import Path
p = Path("js/api/client.js")
text = p.read_text()

old = 'const BACKEND_URL = "http://localhost:8000";'
new = 'const BACKEND_URL = "/api";'

if old in text:
    text = text.replace(old, new, 1)
else:
    if 'const BACKEND_URL =' not in text:
        raise SystemExit("Impossible de trouver la constante BACKEND_URL dans js/api/client.js")
    import re
    text, n = re.subn(r'const\s+BACKEND_URL\s*=\s*.*?;', new, text, count=1, flags=re.S)
    if n == 0:
        raise SystemExit("Impossible de patcher BACKEND_URL proprement")

p.write_text(text)
PY

echo "==> Création du Dockerfile"
cat > Dockerfile <<'EOF'
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
COPY app.js /usr/share/nginx/html/app.js
COPY css /usr/share/nginx/html/css
COPY js /usr/share/nginx/html/js

EXPOSE 80
EOF

echo "==> Création du nginx.conf"
cat > nginx.conf <<'EOF'
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://deepsleep-api:8000/;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

echo "==> Création du .dockerignore"
cat > .dockerignore <<'EOF'
.git
.gitignore
.github
node_modules
dist
build
*.log
.DS_Store
README.refactor.txt
EOF

echo "==> Création du workflow GitHub Actions"
cat > .github/workflows/frontend-ci.yml <<'EOF'
name: DeepSleep Frontend CI/CD

on:
  workflow_dispatch:
  push:
    branches:
      - '**'
  pull_request:
    branches:
      - '**'

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: deepsleep-frontend

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    permissions:
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set metadata
        id: meta
        shell: bash
        run: |
          BRANCH_NAME_SANITIZED=$(echo "${{ github.ref_name }}" | tr '[:upper:]' '[:lower:]' | tr '_' '-' | tr '/' '-')
          SHA_SHORT=$(git rev-parse --short HEAD)
          IMAGE_TAG="${BRANCH_NAME_SANITIZED}.${SHA_SHORT}"

          echo "branch_name_sanitized=$BRANCH_NAME_SANITIZED" >> "$GITHUB_OUTPUT"
          echo "sha_short=$SHA_SHORT" >> "$GITHUB_OUTPUT"
          echo "image_tag=$IMAGE_TAG" >> "$GITHUB_OUTPUT"

      - name: Static file sanity checks
        shell: bash
        run: |
          test -f index.html
          test -f app.js
          test -f js/api/client.js
          test -d css
          test -d js

      - name: Lint nginx config by building image
        shell: bash
        run: |
          docker build -t local/deepsleep-frontend:test .

      - name: Configure AWS credentials
        if: github.event_name != 'pull_request'
        uses: aws-actions/configure-aws-credentials@v5
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        if: github.event_name != 'pull_request'
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Ensure ECR repository exists
        if: github.event_name != 'pull_request'
        shell: bash
        run: |
          aws ecr describe-repositories --repository-names "${{ env.ECR_REPOSITORY }}" >/dev/null 2>&1 || \
          aws ecr create-repository --repository-name "${{ env.ECR_REPOSITORY }}"

      - name: Set up Docker Buildx
        if: github.event_name != 'pull_request'
        uses: docker/setup-buildx-action@v3

      - name: Build and push Docker image
        if: github.event_name != 'pull_request'
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ steps.meta.outputs.image_tag }}
            ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ steps.meta.outputs.branch_name_sanitized }}-latest

      - name: Output image reference
        if: github.event_name != 'pull_request'
        shell: bash
        run: |
          echo "Pushed image:"
          echo "${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ steps.meta.outputs.image_tag }}"
EOF

echo "==> Création d'un README.docker.txt"
cat > README.docker.txt <<'EOF'
Frontend dockerisé avec Nginx.

Accès public attendu:
  http://deepsleep.sarfatech.com:8080

Le frontend parle au backend via:
  /api

Nginx reverse-proxye /api vers:
  http://deepsleep-api:8000/
EOF

echo
echo "Terminé."
echo
echo "Fichiers créés:"
echo "  - Dockerfile"
echo "  - nginx.conf"
echo "  - .dockerignore"
echo "  - .github/workflows/frontend-ci.yml"
echo "  - README.docker.txt"
echo
echo "Fichier modifié:"
echo "  - js/api/client.js"
echo
echo "Teste localement avec:"
echo "  docker build -t deepsleep-frontend:local ."
