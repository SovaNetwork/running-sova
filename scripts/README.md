### **The scripts folder provides resources for running tests against the Sova Network.**

## network_testing
Combine foundry tooling with Bitcoin tooling to manipulate chain state.

- [dev-double-spend-test-transfer.sh](/scripts/network_testing/dev-double-spend-test-transfer.sh) - Test sentinel locks
- [/scripts/network_testing/dev-double-spend-test-withdraw.sh](/scripts/network_testing/dev-double-spend-test-withdraw.sh) - Test sentinel locks + reverts + withdrawal

## 1559_validate
Inject EIP1559 txs into Sova blocks. Set the number of tx's/block in the docker-config file you are running. `--dev.block-max-transactions 4`

> Execute these from inside the ./scripts/1559_validate/ folder

1. Create the environment
```
python3 -m venv env
```

2. Activate the environment
```
source env/bin/activate
```

3. Install required packages
```
pip install eth_account web3
```

4. Run a script
```bash
# create signed transactions and store artifacts
python3 generate_transactions.py

# broadcast block txs to the node
python3 inject_single_block.py ../eip1559_blocks/block1.json

# validate transactions were successful
python3 validate.py 1
```

5. Deactivate when done
```
deactivate
```