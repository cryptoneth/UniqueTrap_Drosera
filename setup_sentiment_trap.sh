#!/usr/bin/env bash
# Sentiment Trap bootstrap helper
#
# This script wires together the exact workflow documented in README.md:
#  - copies the guide into a fresh working directory
#  - deploys ResponseContract + ChatGPTInfoStore via Foundry
#  - registers the trap with drosera apply
#  - prepares a single-operator docker stack
#
# The operator private key is only kept in-memory; never paste it into a file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_WORKDIR="${ROOT_DIR}/sentiment-trap-$(date +%Y%m%d-%H%M%S)"

command -v forge >/dev/null 2>&1 || { echo "forge not found in PATH"; exit 1; }
command -v drosera >/dev/null 2>&1 || { echo "drosera CLI not found in PATH"; exit 1; }
command -v drosera-operator >/dev/null 2>&1 || { echo "drosera-operator binary not found"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "docker not found in PATH"; exit 1; }

read -r -p "Working directory [${DEFAULT_WORKDIR}]: " WORKDIR
WORKDIR="${WORKDIR:-$DEFAULT_WORKDIR}"
mkdir -p "${WORKDIR}"

read -r -p "Operator wallet address (0x...): " OPERATOR_ADDRESS
read -r -p "Primary Hoodi RPC URL: " RPC_URL
read -r -p "Optional backup RPC URL [https://0xrpc.io/hoodi]: " BACKUP_RPC_URL
BACKUP_RPC_URL="${BACKUP_RPC_URL:-https://0xrpc.io/hoodi}"
read -r -s -p "Operator PRIVATE KEY (0x...): " PRIVATE_KEY
echo

[[ "${OPERATOR_ADDRESS}" =~ ^0x[0-9a-fA-F]{40}$ ]] || { echo "Invalid operator address"; exit 1; }
[[ "${PRIVATE_KEY}" =~ ^0x[0-9a-fA-F]{64}$ ]] || { echo "Invalid private key length"; exit 1; }

trap_name="sentiment_trap_$(date +%s)"

echo ">> Copying guide into ${WORKDIR}"
rsync -a --exclude '.git' --exclude 'sentiment-trap-guide' "${ROOT_DIR}/" "${WORKDIR}/" >/dev/null

pushd "${WORKDIR}" >/dev/null

export SENTIMENT_RPC="${RPC_URL}"
export PRIVATE_KEY_TMP="${PRIVATE_KEY}"
export DROSERA_PRIVATE_KEY="${PRIVATE_KEY}"

echo ">> Deploying ResponseContract"
forge script script/DeployResponseContract.s.sol:DeployResponseContract \
  --rpc-url "${SENTIMENT_RPC}" \
  --chain-id 560048 \
  --broadcast \
  --private-key "${PRIVATE_KEY_TMP}" >/dev/null

RESPONSE_CONTRACT=$(jq -r '.transactions[] | select(.contractName=="ResponseContract") | .contractAddress' \
  broadcast/DeployResponseContract.s.sol/560048/run-latest.json | tail -n 1)

[[ "${RESPONSE_CONTRACT}" =~ ^0x[0-9a-fA-F]{40}$ ]] || { echo "Failed to parse ResponseContract address"; exit 1; }
echo "   ResponseContract @ ${RESPONSE_CONTRACT}"

echo ">> Deploying ChatGPT contracts"
forge script script/DeployChatGPTContracts.s.sol:DeployChatGPTContracts \
  --rpc-url "${SENTIMENT_RPC}" \
  --chain-id 560048 \
  --broadcast \
  --private-key "${PRIVATE_KEY_TMP}" >/dev/null

INFO_STORE=$(jq -r '.transactions[] | select(.contractName=="ChatGPTInfoStore") | .contractAddress' \
  broadcast/DeployChatGPTContracts.s.sol/560048/run-latest.json | tail -n 1)

[[ "${INFO_STORE}" =~ ^0x[0-9a-fA-F]{40}$ ]] || { echo "Failed to parse ChatGPTInfoStore address"; exit 1; }
echo "   ChatGPTInfoStore @ ${INFO_STORE}"

echo ">> Updating SentimentTrap with info-store address"
sed -i "s/^    address private constant CHATGPT_INFO_STORE_ADDRESS.*/    address private constant CHATGPT_INFO_STORE_ADDRESS = ${INFO_STORE};/" \
  src/SentimentTrap.sol
forge build >/dev/null

echo ">> Writing drosera.toml"
cat > drosera.toml <<EOF
ethereum_rpc = "${SENTIMENT_RPC}"
drosera_rpc  = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048
drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"

[traps.${trap_name}]
name = "Sentiment Trap"
description = "Alerts when NEGATIVE sentiment appears in ChatGPT feed"
path = "out/SentimentTrap.sol/SentimentTrap.json"
response_contract = "${RESPONSE_CONTRACT}"
response_function = "respond(bytes)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 1
private_trap = true
whitelist = ["${OPERATOR_ADDRESS}"]
EOF

echo ">> Registering trap with drosera"
drosera apply --private-key "${PRIVATE_KEY_TMP}" --non-interactive

TRAP_CONFIG_ADDR=$(grep -A1 '[trap' -n drosera.toml | awk '/address/{print $3}' | tail -n1 | tr -d '"')

echo ">> drosera dryrun confirmation"
drosera dryrun --private-key "${PRIVATE_KEY_TMP}"

cat <<MSG

Your trap config address: ${TRAP_CONFIG_ADDR}
Response contract:        ${RESPONSE_CONTRACT}
ChatGPT info store:       ${INFO_STORE}

Please fund the trap with Bloom (Hoodi ETH) in the Drosera dashboard BEFORE opting in.
Once funded, press Enter to continue with operator setup.
MSG
read -r

echo ">> Registering operator BLS key"
drosera-operator register \
  --eth-rpc-url "${SENTIMENT_RPC}" \
  --eth-chain-id 560048 \
  --eth-private-key "${PRIVATE_KEY_TMP}" \
  --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D

echo ">> Preparing Docker stack"
cat > drosera-operator/.env <<EOF
ETH_PRIVATE_KEY=${PRIVATE_KEY_TMP}
VPS_IP=${HOSTNAME:-127.0.0.1}
EOF

cat > drosera-operator/docker-compose.yaml <<EOF
services:
  drosera:
    image: ghcr.io/drosera-network/drosera-operator:latest
    container_name: drosera-node
    network_mode: host
    volumes:
      - drosera_data:/data
    command: >
      node
        --db-file-path /data/drosera.db
        --network-p2p-port 31313
        --server-port 31314
        --eth-rpc-url ${SENTIMENT_RPC}
        --eth-backup-rpc-url ${BACKUP_RPC_URL}
        --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D
        --eth-private-key \${ETH_PRIVATE_KEY}
        --listen-address 0.0.0.0
        --network-external-p2p-address \${VPS_IP}
        --disable-dnr-confirmation true
    restart: always

volumes:
  drosera_data:
EOF

echo ">> Opening firewall ports (requires sudo; skip if using a custom firewall)"
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow 31313/tcp >/dev/null || true
  sudo ufw allow 31313/udp >/dev/null || true
  sudo ufw allow 31314/tcp >/dev/null || true
fi

echo ">> Starting docker compose"
pushd drosera-operator >/dev/null
docker compose up -d
popd >/dev/null

cat <<'MSG'

Docker operator is running. Give it a minute to index blocks, then:
  1. Visit the Drosera dashboard.
  2. Opt in your operator wallet (0x...) to trap address shown above.
  3. Monitor logs with: docker logs -f drosera-node

Remember to unset PRIVATE_KEY from your shell when done.
MSG

unset SENTIMENT_RPC PRIVATE_KEY_TMP DROSERA_PRIVATE_KEY
popd >/dev/null
