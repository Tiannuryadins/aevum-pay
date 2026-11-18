#!/usr/bin/env bash
# claim-faucet.sh — claim testnet tokens from the on-chain QDay faucets.
#
# Requires a little tQDAY for gas. For a brand-new wallet with 0 tQDAY, get
# the first drip from https://faucet.qday.info (captcha-gated relay) first,
# then this script can top up directly on-chain (per-address cooldown applies).
#
#   tQDAY faucet : 0x33d19Bde2e1798c13808f17BfBa1780b28e4bACC (claim 5 tQDAY)
#   tUSD8 faucet : 0x4551B2a3dE4F43e6613E23edf798Ab4FB0211564 (claim 1 tUSD8)
#   Both expose claim(address to). Source: faucet.qday.info /gasapi/info.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source .env

RPC="https://rpc-test.qday.info"
TQDAY_FAUCET="0x33d19Bde2e1798c13808f17BfBa1780b28e4bACC"
TUSD8_FAUCET="0x4551B2a3dE4F43e6613E23edf798Ab4FB0211564"
TUSD8="0x456569838f1d43009A91ebA4263147Afd7233483"

echo "Deployer: $DEPLOYER_ADDRESS"
echo "tQDAY before: $(cast balance "$DEPLOYER_ADDRESS" --rpc-url "$RPC" --ether)"
echo "tUSD8 before: $(cast call "$TUSD8" "balanceOf(address)" "$DEPLOYER_ADDRESS" --rpc-url "$RPC")"

echo "--- claiming 5 tQDAY ---"
cast send "$TQDAY_FAUCET" "claim(address)" "$DEPLOYER_ADDRESS" \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json | grep -E '"transactionHash"|"status"' || true

echo "--- claiming 1 tUSD8 ---"
cast send "$TUSD8_FAUCET" "claim(address)" "$DEPLOYER_ADDRESS" \
  --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json | grep -E '"transactionHash"|"status"' || true

echo "tQDAY after: $(cast balance "$DEPLOYER_ADDRESS" --rpc-url "$RPC" --ether)"
echo "tUSD8 after: $(cast call "$TUSD8" "balanceOf(address)" "$DEPLOYER_ADDRESS" --rpc-url "$RPC")"
echo "Explorer: https://explorer-test.qday.info/address/$DEPLOYER_ADDRESS"
