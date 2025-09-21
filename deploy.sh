#!/usr/bin/env bash
set -euo pipefail

HOST="${1:?host/ip required}"
BRANCH="${2:-dev}"
TAG="${3:-${BRANCH}-latest}"

: "${DOCKERHUB_USER:?set DOCKERHUB_USER}"
: "${APP_NAME:=devops-build}"

IMAGE="${DOCKERHUB_USER}/${APP_NAME}:${TAG}"

cat > /tmp/deploy_remote.sh <<'EOS'
set -euo pipefail
docker pull "${IMAGE}"
docker rm -f "${APP_NAME}" 2>/dev/null || true
docker run -d --name "${APP_NAME}" -p 80:80 --restart unless-stopped "${IMAGE}"
docker ps --filter "name=${APP_NAME}"
EOS

scp /tmp/deploy_remote.sh "ec2-user@${HOST}:/tmp/deploy_remote.sh"
ssh "ec2-user@${HOST}" "APP_NAME='${APP_NAME}' IMAGE='${IMAGE}' bash /tmp/deploy_remote.sh"
echo "[Deploy] Completed to ${HOST} with ${IMAGE}"
