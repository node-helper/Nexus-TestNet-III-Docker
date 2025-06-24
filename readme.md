# Nexus Node Manager

A simple Bash script to install, run, manage, and monitor Nexus Airdrop Nodes using Docker containers.

## Features

* Install Docker and Cron automatically if missing
* Build a Docker image for the Nexus node
* Run multiple Nexus nodes in isolated Docker containers by NODE\_ID
* View status, CPU, and memory usage of all running nodes
* View logs of any node
* Remove specific or all nodes cleanly
* Automatic daily log cleanup via cron

## Requirements

* Ubuntu 24.04 (tested)
* `bash` shell
* `docker` and `cron` (the script installs them if missing)
* Internet access to download Docker and Nexus CLI

## Usage

1. **Run the script:**

```bash
chmod +x nexus-node-manager.sh
./nexus-node-manager.sh
```

2. **Menu options:**

* **1 - Install & Run Node:** Enter the `NODE_ID` to build and start a new node container.
* **2 - View Status of All Nodes:** Show all nodes with status, CPU, and memory usage.
* **3 - Remove Specific Node:** Select nodes to remove by number.
* **4 - View Node Logs:** Select a node to follow its logs.
* **5 - Remove All Nodes:** Remove all running and stopped nodes after confirmation.
* **6 - Exit:** Quit the script.

## How it works

* The script builds a Docker image based on Ubuntu 24.04 with Nexus CLI installed.
* It runs Nexus nodes inside Docker containers named `nexus-node-<NODE_ID>`.
* Logs are stored on the host under `/root/nexus_logs/nexus-<NODE_ID>.log`.
* A cron job cleans node logs daily to avoid disk usage growth.
* Uses `screen` inside the container to run Nexus nodes in the background.

## Configuration

* Base container name, image name, and log directory can be changed by editing variables at the top of the script.
* Dockerfile and entrypoint script are generated dynamically during the build process.

## Notes

* Make sure your system supports Docker and has adequate permissions.
* The script assumes Ubuntu 24.04; adapt Dockerfile for other distros if needed.
* Logs and containers are cleaned up carefully; double-check before removing all nodes.
