# Sentiment Trap Build Log

This repository documents a single-operator Drosera trap I assembled from start to finish. It bridges a custom sentiment feed (powered by OpenAI text) with a Drosera response contract running on the Hoodi network. Everything here is meant to be reproducible with your own wallet and infrastructure.

---

## 1. Repository Layout

```
sentiment-trap-guide/
├── README.md            # this document
├── drosera.toml         # template Drosera configuration (edit before applying)
├── foundry.toml         # Foundry config with placeholder endpoints
├── src/                 # Solidity contracts (SentimentTrap + supporting code)
├── scripts/             # Python sentiment feeder
└── test/                # Forge tests (drift + consensus examples)
```

Only `README.md`, `drosera.toml`, `foundry.toml`, `src/`, `scripts/`, and `test/` are tracked—build artefacts (`out/`, `cache/`, etc.) are intentionally excluded.

## 2. Prerequisites

1. **Wallet** with Hoodi testnet ETH (keep the private key in a secure shell; never commit it).
2. **RPC endpoints** for Hoodi (use a reliable provider; I used Ankr during setup).
3. **Tooling**: Docker, Foundry (`forge`, `cast`), Drosera CLI, and the Drosera operator binaries.
4. **Ports**: expose TCP/UDP 31313 and TCP 31314 on your VPS for Drosera’s P2P + HTTP interfaces.

I export the sensitive bits in my shell before running any scripts:

```bash
export PRIVATE_KEY=0xYourPrivateKey
export SENTIMENT_RPC=https://your-hoodi-rpc
source ~/.bashrc
forge --version
drosera --version
```

---

## 3. Deploy Smart Contracts

All commands run from this repo’s root. Replace the placeholder environment variables with your own values.

### 3.1 Response Contract
```bash
forge script script/DeployResponseContract.s.sol:DeployResponseContract \
  --rpc-url "$SENTIMENT_RPC" \
  --chain-id 560048 \
  --broadcast \
  --private-key "$PRIVATE_KEY"
```
Record the emitted address (e.g. `0xff47…58e`). This contract exposes `respond(bytes)` and `handleDrift(string)`; the trap will call the bytes variant.

### 3.2 ChatGPT Info Store & Sentiment Trap Bytecode
```bash
forge script script/DeployChatGPTContracts.s.sol:DeployChatGPTContracts \
  --rpc-url "$SENTIMENT_RPC" \
  --chain-id 560048 \
  --broadcast \
  --private-key "$PRIVATE_KEY"
```
The script deploys two components:

* `ChatGPTInfoStore` – the contract the off-chain service updates.
* `SentimentTrap` bytecode – stored in `out/SentimentTrap.sol/SentimentTrap.json` and used by Drosera.

Update `src/SentimentTrap.sol` to hardcode the new info-store address and rebuild:
```solidity
address private constant CHATGPT_INFO_STORE_ADDRESS = 0xYourInfoStore;
```
```bash
forge build
```

---

## 4. Configure Drosera

`drosera.toml` drives the trap registration. Keep only the sentiment trap section:

```toml
ethereum_rpc = "https://your-hoodi-rpc"
drosera_rpc  = "https://relay.hoodi.drosera.io"
eth_chain_id = 560048

drosera_address = "0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D"

[traps.sentiment_trap]
name                = "Sentiment Trap"
description         = "Alerts when NEGATIVE sentiment appears in ChatGPT feed"
path                = "out/SentimentTrap.sol/SentimentTrap.json"
response_contract   = "0xYourResponseContract"
response_function   = "respond(bytes)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size   = 1
private_trap        = true
whitelist           = ["0xYourOperatorAddress"]
```

Apply it:
```bash
cd /path/to/sentiment-trap-guide
drosera apply --private-key "$PRIVATE_KEY" --non-interactive
```
You should see a new trap config address in the CLI output (e.g. `0xb0B0…5407`).

Run a quick dry-run sanity check:
```bash
drosera dryrun --private-key "$PRIVATE_KEY"
```
Expect a single entry for `sentiment_trap` with `shouldRespond = false` unless your info store already contains the `NEGATIVE` keyword.

---

## 5. Register and Run Operator

### 5.1 Register BLS keys
```bash
drosera-operator register \
  --eth-rpc-url "$SENTIMENT_RPC" \
  --eth-chain-id 560048 \
  --eth-private-key "$PRIVATE_KEY" \
  --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D
```

### 5.2 Dockerized node
Clone the reference deployment scripts and adapt them to your infrastructure. My Docker compose (host networking, single trap) looks like this:

```yaml
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
        --eth-rpc-url https://your-hoodi-rpc
        --eth-backup-rpc-url https://0xrpc.io/hoodi
        --drosera-address 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D
        --eth-private-key ${ETH_PRIVATE_KEY}
        --listen-address 0.0.0.0
        --network-external-p2p-address ${VPS_IP}
        --disable-dnr-confirmation true
    restart: always

volumes:
  drosera_data:
```

`.env` should define:
```bash
ETH_PRIVATE_KEY=0xYourPrivateKey
VPS_IP=your.public.ip.address
```

Then:
```bash
docker compose up -d
docker logs -f drosera-node
```

Give the node a few minutes to index the latest blocks. Health check: `curl http://<VPS_IP>:31314/health` should return “Method not allowed” (meaning the HTTP port is reachable).

---

## 6. Off-chain Sentiment Feeder (Optional)

`scripts/chatgpt_service/main.py` pushes OpenAI sentiment summaries to the `ChatGPTInfoStore`. Set the following environment variables before running it:

```
RPC_URL=https://your-hoodi-rpc
PRIVATE_KEY=0xYourWalletKey
CHATGPT_INFO_STORE_ADDRESS=0xYourInfoStore
OPENAI_API_KEY=sk-...
```

Launch the feeder with:
```bash
python scripts/chatgpt_service/main.py
```
The script iterates through sample texts; customize it to pipe real data.

---

## 7. Validation Checklist

1. `drosera dryrun` reports `sentiment_trap` with `trapAddress = 0xYourTrapConfig`.
2. `docker logs drosera-node` shows steady `ShouldRespond` entries for the trap.
3. Drosera dashboard eventually flips the trap column green; if it stays red, leave the node running for a few more block cycles or double-check the inbound ports.

---

## 8. Troubleshooting

* **Batch size too large**: some public RPCs reject large block ranges. Either retry (the operator does this automatically) or use a private RPC provider.
* **Seed node unreachable**: ensure UDP/TCP 31313 + TCP 31314 are open to the world, or adopt host networking as shown above.
* **Opt-in panics**: the CLI occasionally panics on submission metadata; rely on the Docker service to reconnect on startup if the panic occurs.

This repository captures the working state after the full setup. Replace the placeholder values with your own credentials when reproducing the build.
