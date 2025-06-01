# Using op-deployer To Generate Sova Chain Artifacts

This is a "how to" document on how Sova uses the op-deployer tool to generate OP chain artifacts.

**The genesis.json and rollup.json file in the `testnet` folder were created using the instructions below.**

To see the changes made to the deployment scripts used by op-deployer see the forked [SovaNetwork/optimism](https://github.com/SovaNetwork/optimism) repo on branch [op-deployer-0.3.0](https://github.com/SovaNetwork/optimism/tree/op-deployer-0.3.0). You can view the diff here: [https://github.com/SovaNetwork/optimism/compare/ef7a933ca7f3d27ac40406f87fea25e0c3ba2016...3377526e5134beba574b5cb2cef5d5667e8167d5](https://github.com/SovaNetwork/optimism/compare/ef7a933ca7f3d27ac40406f87fea25e0c3ba2016...3377526e5134beba574b5cb2cef5d5667e8167d5)

### Step 1
Download op-deployer from Optimism [releases page](https://github.com/ethereum-optimism/optimism/releases). It is very important to be cognizant of the release version you choose here as it directly relates to the op-contracts release version that is supported. When upgrading to new releases of op-deployer, look at the pre-populated contracts field in the intent.toml and use that as the base of the fork to make Sova predeploy changes on top of.

```
➜  Downloads sudo mv op-deployer-0.3.0-rc.3-darwin-arm64/op-deployer /usr/local/bin/
➜  Downloads ..
➜  ~ op-deployer --version
[1]    43807 killed     op-deployer --version
➜  ~ op-deployer --version
op-deployer version 0.3.0-rc.5-b725dd78-2025-03-15T15:39:09Z
```
> NOTE: For macOS users: When you run op-deployer for the first time your system settings will block it. Go to settings -> Privacy & Security and click allow on the blocked program execution.

### Step 2
Initialize `intent.toml` and `state.json` files, that will be used to create chain artifacts.

```
op-deployer init \
  --l1-chain-id 11155111 \
  --l2-chain-ids 120893 \
  --workdir ~/running-sova/config/testnet \
  --intent-type standard-overrides
```
- After generating the intent.toml file with this command, modify the contracts path to point to local `/forge-artifacts` folder.
    - Change `tag://op-contracts/v3.0.0-rc.2` to local file path `file:///Users/powvt/optimism/packages/contracts-bedrock/forge-artifacts/`.
- Update the 0x0 addresses in intent.toml file to final addresses for the chain.
- Verify the `fundDevAccounts` flag is what you want.
- Verify `useInterop` flag is what you want.


### Step 3
Deploy your OP chain.

> NOTE: Prior to running this next command, remember to remove any previous cached deployments with: `rm -rf ~/.cache/op-deployer`
```
op-deployer --cache-dir ~/.cache/op-deployer apply \
  --workdir ~/running-sova/config/testnet \
  --l1-rpc-url $L1_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Step 4
Generate genesis files and chain information

```
op-deployer inspect genesis --workdir ~/running-sova/config/testnet 120893 > ~/running-sova/config/testnet/genesis.json
op-deployer inspect rollup --workdir ~/running-sova/config/testnet 120893 > ~/running-sova/config/testnet/rollup.json
```