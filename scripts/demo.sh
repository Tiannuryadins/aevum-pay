#!/usr/bin/env bash
# demo.sh — run the full AevumPay payment flow on Aevum testnet and print
# every transaction hash + explorer link.
#
# Prerequisites:
#   1. AevumPay deployed (see deployments/aevum-testnet.json, or pass address
#      as $1). Deploy with: forge script script/Deploy.s.sol --rpc-url aevum --broadcast
#   2. Deployer holds >= 0.50 tUSD8 (one faucet drip = 1 tUSD8) + a little tQDAY.
#      Claim via scripts/claim-faucet.sh (or https://faucet.qday.info first).
#
# Flow: approve 0.50 tUSD8 -> create invoice -> fund (escrow) -> confirm
# delivery (release to merchant) -> verify balances + invoice status.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source .env

RPC="https://rpc-test.qday.info"
EXPLORER="https://explorer-test.qday.info"
TUSD8="0x456569838f1d43009A91ebA4263147Afd7233483"
AMOUNT=500000          # 0.50 tUSD8 (6 decimals)
EXPIRY=3600            # 1 hour
MEMO="demo-order-001"

if [ $# -ge 1 ]; then
  PAY="$1"
elif [ -f deployments/aevum-testnet.json ]; then
  PAY=$(python3 -c "import json; print(json.load(open('deployments/aevum-testnet.json'))['aevumPay'])")
else
  echo "Usage: $0 <AevumPay address>  (or deploy first; see deployments/aevum-testnet.json)" >&2
  exit 1
fi

echo "== AevumPay end-to-end demo =="
echo "AevumPay : $PAY"
echo "Payer    : $DEPLOYER_ADDRESS"
echo "Merchant : $MERCHANT_ADDRESS"
echo "Amount   : 0.50 tUSD8"
echo

bal() { cast call "$TUSD8" "balanceOf(address)" "$1" --rpc-url "$RPC"; }
echo "Payer tUSD8 before   : $(bal "$DEPLOYER_ADDRESS")"
echo "Merchant tUSD8 before: $(bal "$MERCHANT_ADDRESS")"
echo

send() { # $1 = to, $2.. = cast send args; prints tx hash
  cast send "$@" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json | python3 -c "import json,sys; print(json.load(sys.stdin)['transactionHash'])"
}

echo "--- 1. approve 0.50 tUSD8 ---"
TX_APPROVE=$(send "$TUSD8" "approve(address,uint256)" "$PAY" "$AMOUNT")
echo "tx: $TX_APPROVE"
echo "    $EXPLORER/tx/$TX_APPROVE"

echo "--- 2. create invoice ---"
TX_CREATE=$(send "$PAY" "createInvoice(address,uint256,uint256,string)" "$MERCHANT_ADDRESS" "$AMOUNT" "$EXPIRY" "$MEMO")
echo "tx: $TX_CREATE"
echo "    $EXPLORER/tx/$TX_CREATE"
ID=$(cast receipt "$TX_CREATE" --rpc-url "$RPC" --json | python3 -c "
import json,sys
r = json.load(sys.stdin)
# InvoiceCreated is the first log; id is topic[1]
print(int(r['logs'][0]['topics'][1], 16))
")
echo "invoice id: $ID"

echo "--- 3. fund invoice (escrow) ---"
TX_FUND=$(send "$PAY" "fundInvoice(uint256)" "$ID")
echo "tx: $TX_FUND"
echo "    $EXPLORER/tx/$TX_FUND"
echo "escrow balance: $(bal "$PAY")"

echo "--- 4. confirm delivery (release to merchant) ---"
TX_CONFIRM=$(send "$PAY" "confirmDelivery(uint256)" "$ID")
echo "tx: $TX_CONFIRM"
echo "    $EXPLORER/tx/$TX_CONFIRM"

echo
echo "Payer tUSD8 after   : $(bal "$DEPLOYER_ADDRESS")"
echo "Merchant tUSD8 after: $(bal "$MERCHANT_ADDRESS")"
echo "Escrow tUSD8 after  : $(bal "$PAY")"
echo "Invoice status (0=Created 1=Funded 2=Released 3=Refunded 4=Cancelled):"
cast call "$PAY" "getInvoice(uint256)" "$ID" --rpc-url "$RPC"
echo
echo "Contract: $EXPLORER/address/$PAY"
echo "== demo complete =="
