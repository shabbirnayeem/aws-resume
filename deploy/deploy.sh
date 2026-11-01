#!/usr/bin/env bash
# Runs on the Pi via the self-hosted runner: roll out IMAGE:IMAGE_TAG and roll back if it is unhealthy.
set -euo pipefail

: "${IMAGE:?IMAGE is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"

COMPOSE=(docker compose -p portfolio -f "$(dirname "$0")/docker-compose.yml")
CONTAINER=portfolio-web
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:${HOST_PORT:-9123}/healthz}"

deploy() {
   IMAGE_TAG="$1" "${COMPOSE[@]}" pull
   IMAGE_TAG="$1" "${COMPOSE[@]}" up -d --remove-orphans
}

healthy() {
   for _ in $(seq 1 15); do
      if curl -fs "$HEALTH_URL" >/dev/null; then
         return 0
      fi
      sleep 2
   done
   return 1
}

# Network shared with the cloudflared container
docker network inspect tunnel >/dev/null 2>&1 || docker network create tunnel >/dev/null

previous_tag=""
if docker inspect "$CONTAINER" >/dev/null 2>&1; then
   previous_tag=$(docker inspect --format '{{.Config.Image}}' "$CONTAINER" | awk -F: '{print $NF}')
fi

echo "Deploying $IMAGE:$IMAGE_TAG (previous: ${previous_tag:-none})"
deploy "$IMAGE_TAG"

if healthy; then
   echo "Deploy healthy"
   docker image prune -f >/dev/null
   exit 0
fi

echo "Health check failed for $IMAGE:$IMAGE_TAG" >&2
if [[ -n "$previous_tag" && "$previous_tag" != "$IMAGE_TAG" ]]; then
   echo "Rolling back to $IMAGE:$previous_tag" >&2
   deploy "$previous_tag"
   if healthy; then
      echo "Rollback healthy" >&2
   else
      echo "Rollback is also unhealthy" >&2
   fi
fi
exit 1
