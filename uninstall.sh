#!/bin/bash
set -e

BASE_CONTAINER_NAME="nexus-node"
IMAGE_NAME="nexus-node:latest"
LOG_DIR="/root/nexus_logs"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

echo -e "${YELLOW}⚠ This will remove all Nexus nodes, logs, cron jobs, and the Docker image.${RESET}"
read -rp "Are you sure you want to continue? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Remove all containers
echo -e "${GREEN}🗑 Removing all containers matching ${BASE_CONTAINER_NAME}-*...${RESET}"
containers=$(docker ps -a --format '{{.Names}}' | grep "^${BASE_CONTAINER_NAME}-" || true)
for cname in $containers; do
    echo "Removing container: $cname"
    docker rm -f "$cname" 2>/dev/null || true
done

# Remove all cron jobs
echo -e "${GREEN}🧹 Removing associated cron jobs...${RESET}"
find /etc/cron.d -type f -name "nexus-log-cleanup-*" -exec rm -f {} \;

# Delete log directory
if [ -d "$LOG_DIR" ]; then
    echo -e "${GREEN}🧻 Deleting log directory: $LOG_DIR${RESET}"
    rm -rf "$LOG_DIR"
fi

# Remove docker image
echo -e "${GREEN}📦 Removing Docker image: $IMAGE_NAME${RESET}"
docker rmi "$IMAGE_NAME" 2>/dev/null || true

# Optional: Clean dangling Docker resources
echo -e "${GREEN}♻ Cleaning up dangling Docker volumes and images...${RESET}"
docker system prune -f

echo -e "${GREEN}✅ Complete uninstallation finished.${RESET}"
