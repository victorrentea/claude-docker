#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
docker build -t "${CLAUDE_DOCKER_IMAGE:-claude-docker:latest}" .
