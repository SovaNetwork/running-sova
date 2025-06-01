from eth_account import Account
from web3 import Web3
import json

# Dev account private key (default Reth dev mnemonic key)
dev_private_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
acct = Account.from_key(dev_private_key)

chain_id = 120893  # Your custom chainId
nonce = 0  # Adjust as per previous transactions

blocks = {
    "block1.json": [
        {"to": "0xb42a8c62f3278afc9343a8fccd5232cbe8aa5117", "value": 500000000000000, "gas": 21000},
        {"to": "0xc390cc49a32736a58733cf46be42f734dd4f53cb", "value": 700000000000000, "gas": 25000}
    ],
    "block2.json": [
        {"to": "0xb42a8c62f3278afc9343a8fccd5232cbe8aa5117", "value": 1000000000000000, "gas": 200000},
        {"to": "0xc390cc49a32736a58733cf46be42f734dd4f53cb", "value": 1500000000000000, "gas": 200000}
    ],
    "block3.json": [
        {"to": "0xb42a8c62f3278afc9343a8fccd5232cbe8aa5117", "value": 2000000000000000, "gas": 210000},
        {"to": "0xc390cc49a32736a58733cf46be42f734dd4f53cb", "value": 2500000000000000, "gas": 210000}
    ],
    "block4.json": [
        {"to": "0xb42a8c62f3278afc9343a8fccd5232cbe8aa5117", "value": 3000000000000000, "gas": 220000},
        {"to": "0xc390cc49a32736a58733cf46be42f734dd4f53cb", "value": 3500000000000000, "gas": 220000}
    ],
    "block5.json": [
        {"to": "0xb42a8c62f3278afc9343a8fccd5232cbe8aa5117", "value": 4000000000000000, "gas": 230000},
        {"to": "0xc390cc49a32736a58733cf46be42f734dd4f53cb", "value": 4500000000000000, "gas": 230000}
    ]
}

w3 = Web3()

for block_file, tx_list in blocks.items():
    signed_txs = []
    for tx in tx_list:
        checksum_to = w3.to_checksum_address(tx["to"])
        transaction = {
            "nonce": nonce,
            "to": checksum_to,
            "value": tx["value"],
            "gas": tx["gas"],
            "maxPriorityFeePerGas": 2500000000,  # 2.5 Gwei
            "maxFeePerGas": 2500000000,          # 2.5 Gwei
            "chainId": chain_id,
            "type": 2,
            "data": b""
        }

        signed_tx = acct.sign_transaction(transaction).raw_transaction.hex()
        signed_txs.append(signed_tx)
        nonce += 1

    with open(f"../eip1559_blocks/{block_file}", "w") as f:
        json.dump({"block": block_file, "transactions": signed_txs}, f, indent=2)

    print(f"✅ Generated {block_file} with {len(signed_txs)} transactions.")
