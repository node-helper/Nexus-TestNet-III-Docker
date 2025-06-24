#!/bin/bash
set -e

# === Basic Configuration ===
BASE_CONTAINER_NAME="nexus-node"
IMAGE_NAME="nexus-node:latest"
LOG_DIR="/root/nexus_logs"

# === Terminal Colors ===
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# === Display Header ===
function show_header() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "              🚀 Airdrop Adventure Node Manager"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}🔗 Telegram:${RESET} https://t.me/AirdropAdventureX"
    echo -e "${GREEN}📦 GitHub  :${RESET} https://github.com/node-helper"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}


# === Check Docker Installation ===
# === Check Docker Installation and Unmask Services ===
function check_docker() {
    #UPDATE SUSTEM 
    apt update && apt upgrade -y
    # Unmask and enable required services
    for svc in docker containerd docker.socket; do
        if systemctl is-enabled "$svc" 2>/dev/null | grep -q masked; then
            echo -e "${YELLOW}Service $svc is masked. Unmasking...${RESET}"
            systemctl unmask "$svc"
        fi
    done

    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${YELLOW}Docker not found. Installing Docker...${RESET}"
        apt update
        apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update
        apt install -y docker-ce
    fi

    # Unmask again in case apt installs a masked service
    for svc in docker containerd docker.socket; do
        if systemctl is-enabled "$svc" 2>/dev/null | grep -q masked; then
            echo -e "${YELLOW}Service $svc is masked. Unmasking...${RESET}"
            systemctl unmask "$svc"
        fi
        systemctl enable "$svc"
        systemctl start "$svc"
    done
}

# === Check Cron Installation ===
function check_cron() {
    if ! command -v cron >/dev/null 2>&1; then
        echo -e "${YELLOW}Cron is not installed. Installing cron...${RESET}"
        apt update
        apt install -y cron
        systemctl enable cron
        systemctl start cron
    fi
}

# === Build Docker Image ===
function build_image() {
    WORKDIR=$(mktemp -d)
    cd "$WORKDIR"

    cat > Dockerfile <<EOF
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PROVER_ID_FILE=/root/.nexus/node-id

RUN apt-get update && apt-get install -y \\
    curl \\
    screen \\
    bash \\
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSL https://cli.nexus.xyz/ | NONINTERACTIVE=1 sh \\
    && ln -sf /root/.nexus/bin/nexus-network /usr/local/bin/nexus-network

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
EOF

    cat > entrypoint.sh <<EOF
#!/bin/bash
set -e
PROVER_ID_FILE="/root/.nexus/node-id"
if [ -z "\$NODE_ID" ]; then
    echo "NODE_ID is not set"
    exit 1
fi
echo "\$NODE_ID" > "\$PROVER_ID_FILE"
screen -S nexus -X quit >/dev/null 2>&1 || true
screen -dmS nexus bash -c "nexus-network start --node-id \$NODE_ID &>> /root/nexus.log"
sleep 3
if screen -list | grep -q "nexus"; then
    echo "Node is running in the background"
else
    echo "Failed to start node"
    cat /root/nexus.log
    exit 1
fi
tail -f /root/nexus.log
EOF

    docker build -t "$IMAGE_NAME" .
    cd -
    rm -rf "$WORKDIR"
}

# === Run Container ===
function run_container() {
    local node_id=$1
    local container_name="${BASE_CONTAINER_NAME}-${node_id}"
    local log_file="${LOG_DIR}/nexus-${node_id}.log"

    docker rm -f "$container_name" 2>/dev/null || true
    mkdir -p "$LOG_DIR"
    touch "$log_file"
    chmod 644 "$log_file"

    docker run -d --name "$container_name" -v "$log_file":/root/nexus.log -e NODE_ID="$node_id" "$IMAGE_NAME"

    check_cron
    echo "0 0 * * * rm -f $log_file" > "/etc/cron.d/nexus-log-cleanup-${node_id}"
}

# === Uninstall Node ===
function uninstall_node() {
    local node_id=$1
    local cname="${BASE_CONTAINER_NAME}-${node_id}"
    docker rm -f "$cname" 2>/dev/null || true
    rm -f "${LOG_DIR}/nexus-${node_id}.log" "/etc/cron.d/nexus-log-cleanup-${node_id}"
    echo -e "${YELLOW}Node $node_id has been removed.${RESET}"
}

# === Get All Nodes ===
function get_all_nodes() {
    docker ps -a --format "{{.Names}}" | grep "^${BASE_CONTAINER_NAME}-" | sed "s/${BASE_CONTAINER_NAME}-//"
}

# === List All Nodes ===
function list_nodes() {
    show_header
    echo -e "${CYAN}📊 Registered Nodes List:${RESET}"
    echo "--------------------------------------------------------------"
    printf "%-5s %-20s %-12s %-15s %-15s\n" "No" "Node ID" "Status" "CPU" "Memory"
    echo "--------------------------------------------------------------"
    local all_nodes=($(get_all_nodes))
    local failed_nodes=()
    for i in "${!all_nodes[@]}"; do
        local node_id=${all_nodes[$i]}
        local container="${BASE_CONTAINER_NAME}-${node_id}"
        local cpu="N/A"
        local mem="N/A"
        local status="Inactive"
        if docker inspect "$container" &>/dev/null; then
            status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
            if [[ "$status" == "running" ]]; then
                stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}" "$container" 2>/dev/null)
                cpu=$(echo "$stats" | cut -d'|' -f1)
                mem=$(echo "$stats" | cut -d'|' -f2 | cut -d'/' -f1 | xargs)
            elif [[ "$status" == "exited" ]]; then
                failed_nodes+=("$node_id")
            fi
        fi
        printf "%-5s %-20s %-12s %-15s %-15s\n" "$((i+1))" "$node_id" "$status" "$cpu" "$mem"
    done
    echo "--------------------------------------------------------------"
    if [ ${#failed_nodes[@]} -gt 0 ]; then
        echo -e "${RED}⚠ Nodes failed to run (exited):${RESET}"
        for id in "${failed_nodes[@]}"; do
            echo "- $id"
        done
    fi
    read -p "Press Enter to return to menu..."
}

# === View Logs of a Node ===
function view_logs() {
    local all_nodes=($(get_all_nodes))
    if [ ${#all_nodes[@]} -eq 0 ]; then
        echo "No nodes available"
        read -p "Press Enter..."
        return
    fi
    echo "Select a node to view logs:"
    for i in "${!all_nodes[@]}"; do
        echo "$((i+1)). ${all_nodes[$i]}"
    done
    read -rp "Number: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#all_nodes[@]} )); then
        local selected=${all_nodes[$((choice-1))]}
        echo -e "${YELLOW}Showing logs for node: $selected${RESET}"
        docker logs -f "${BASE_CONTAINER_NAME}-${selected}"
    fi
    read -p "Press Enter..."
}

# === Batch Uninstall Nodes ===
function batch_uninstall_nodes() {
    local all_nodes=($(get_all_nodes))
    echo "Enter the node numbers to uninstall (separate by space):"
    for i in "${!all_nodes[@]}"; do
        echo "$((i+1)). ${all_nodes[$i]}"
    done
    read -rp "Numbers: " input
    for num in $input; do
        if [[ "$num" =~ ^[0-9]+$ ]] && (( num > 0 && num <= ${#all_nodes[@]} )); then
            uninstall_node "${all_nodes[$((num-1))]}"
        else
            echo "Skipping: $num"
        fi
    done
    read -p "Press Enter..."
}

# === Uninstall All Nodes ===
function uninstall_all_nodes() {
    local all_nodes=($(get_all_nodes))
    echo "Are you sure you want to uninstall ALL nodes? (y/n)"
    read -rp "Confirm: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        for node in "${all_nodes[@]}"; do
            uninstall_node "$node"
        done
        echo "All nodes have been removed."
    else
        echo "Cancelled."
    fi
    read -p "Press Enter..."
}

# === MAIN MENU ===
while true; do
    show_header
    echo -e "${GREEN} 1.${RESET} ➕ Install & Run Node"
    echo -e "${GREEN} 2.${RESET} 📊 View Status of All Nodes"
    echo -e "${GREEN} 3.${RESET} ❌ Remove Specific Node"
    echo -e "${GREEN} 4.${RESET} 🧾 View Node Logs"
    echo -e "${GREEN} 5.${RESET} 💥 Remove All Nodes"
    echo -e "${GREEN} 6.${RESET} 🚪 Exit"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -rp "Choose an option (1-6): " choice
    case $choice in
        1)
            check_docker
            read -rp "Enter NODE_ID: " NODE_ID
            [ -z "$NODE_ID" ] && echo "NODE_ID cannot be empty." && read -p "Press Enter..." && continue
            build_image
            run_container "$NODE_ID"
            read -p "Press Enter..."
            ;;
        2) list_nodes ;;
        3) batch_uninstall_nodes ;;
        4) view_logs ;;
        5) uninstall_all_nodes ;;
        6) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice."; read -p "Press Enter..." ;;
    esac
done
