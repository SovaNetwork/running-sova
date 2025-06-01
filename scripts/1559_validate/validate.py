# set `--dev` and `--dev.block-max-transactions 4` flag in reth to run this script

from web3 import Web3
import json
import sys

if len(sys.argv) != 2:
    print("Usage: python validate_block.py <block_number>")
    sys.exit(1)

block_num = int(sys.argv[1])
w3 = Web3(Web3.HTTPProvider("http://127.0.0.1:8545"))

TOTAL_SYSTEM_TRANSACTIONS = 2

block = w3.eth.get_block(block_num, full_transactions=True)
with open(f"../eip1559_blocks/block{block_num}.json") as f:
    block_data = json.load(f)

intended_txs = block_data["transactions"]
actual_txs = block.transactions

intended_tx_count = len(intended_txs)
actual_tx_count = len(actual_txs)

gas_used = block.gasUsed
gas_limit = block.gasLimit

print(f"Block {block_num}: intended {intended_tx_count} tx, actual {actual_tx_count} tx, gasUsed={gas_used}, gasLimit={gas_limit}")

assert actual_tx_count == intended_tx_count + TOTAL_SYSTEM_TRANSACTIONS, f"Block {block_num} transaction count mismatch!"
assert gas_used <= gas_limit, f"Block {block_num} exceeded gas limit!"

# Validate each transaction individually (excluding system transactions)
for intended_raw_tx, actual_tx in zip(intended_txs, actual_txs[TOTAL_SYSTEM_TRANSACTIONS:]):
    actual_raw_tx = w3.eth.get_raw_transaction(actual_tx.hash).hex()
    assert intended_raw_tx.lower() == actual_raw_tx.lower(), \
        f"Mismatch in transactions for Block {block_num}! Intended: {intended_raw_tx}, Actual: {actual_raw_tx}"

for tx in actual_txs:
    receipt = w3.eth.get_transaction_receipt(tx.hash)
    assert receipt.status == 1, f"Tx {tx.hash.hex()} failed!"

print(f"Block {block_num} validated successfully.")
