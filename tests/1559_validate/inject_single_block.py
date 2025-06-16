import json
import sys
from web3 import Web3

# Configuration
ETH_RPC = "http://127.0.0.1:8545"
ENGINE_RPC = "http://127.0.0.1:8551"

w3 = Web3(Web3.HTTPProvider(ETH_RPC))


def inject_transactions(block_file):
    with open(block_file) as f:
        txs = json.load(f)["transactions"]

    print(f"\nInjecting transactions from {block_file}...")
    for raw_tx in txs:
        tx_hash = w3.eth.send_raw_transaction(w3.to_bytes(hexstr=raw_tx))
        print(f" -> Sent tx {tx_hash.hex()}")

    print("✅ Block injection completed successfully.\n")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 inject_single_block.py path_to_block.json")
        sys.exit(1)

    block_file = sys.argv[1]
    inject_transactions(block_file)
