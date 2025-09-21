#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:-dev}"
TAG="${2:-$(date +%Y%m%d-%H%M%S)}"

: "${DOCKERHUB_USER:?set DOCKERHUB_USER}"
: "${APP_NAME:=devops-build}"

IMAGE="${DOCKERHUB_USER}/${APP_NAME}:${TAG}"

echo "[Build] Building image ${IMAGE} (branch=${BRANCH})"
docker build -t "${IMAGE}" .

if [[ -n "${DOCKERHUB_PASS:-}" ]]; then
  echo "${DOCKERHUB_PASS}" | docker login -u "${DOCKERHUB_USER}" --password-stdin
else
  docker login -u "${DOCKERHUB_USER}"
fi

echo "[Push] Pushing ${IMAGE}"
docker push "${IMAGE}"

CHANNEL_TAG="${BRANCH}-latest"
docker tag "${IMAGE}" "${DOCKERHUB_USER}/${APP_NAME}:${CHANNEL_TAG}"
docker push "${DOCKERHUB_USER}/${APP_NAME}:${CHANNEL_TAG}"

echo "[Done] Pushed ${IMAGE} and ${CHANNEL_TAG}"
