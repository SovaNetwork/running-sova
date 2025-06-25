# Sova Chain Artifacts and Chain Deployment Configurations

**Contents**
1. [Using op-deployer to generate Sova chain artifacts](#using-op-deployer-to-generate-sova-chain-artifacts)
2. [Using optimism-package to deploy using op-deployer under the hood](#using-optimism-package-to-deploy-using-op-deployer-under-the-hood)

## Using op-deployer To Generate Sova Chain Artifacts

This is a section of notes and other resources regarding how Sova uses the op-deployer tool to generate OP chain artifacts.

**The genesis.json and rollup.json file in the `testnet-sepolia` folder were created using the instructions below.**

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
- Update addresses in intent.toml file to final addresses for the chain genesis.
  - It is important to note that the addresses used here will also be needed in the docker .env file when running the compose files...
    - admin
    - batcher
    - proposer
    - sequencer
    - challenger
- Verify the `fundDevAccounts` flag is what you want.
- Verify `useInterop` flag is what you want.

### Step 3
Triple check the local forge-artifacts. Use `forge clean` and `forge build` to re-generate these artifacts. Ensure all owner roles and deployment params are correct.

> NOTE: The `testnet-sepolia` chain was created using the `op-deployer-0.3.0` branch in SovaNetwork/optimism repo at commit hash `4f082df7f6b157d7f10a15bc7ab1c891fa7b6575`.

> **VERY IMPORTANT NOTE:** There is a hack in the SovaNetwork/optimism repo where where you **CANNOT** import SovaNetwork/contracts with `forge install SovaNetwork/contracts@v0.0.9` because the contracts will get compiled differently if they are imported vs in the local `src/L2/sova/` folder. This breaks the `scripts/L2Genesis.s.sol` file because there will be no `<contract-name>.json` to read from there are different files like `<contract-name>.default.json` and `<contract-name>.dispute.json` due to the way the foundry.toml file is configured with different 'profiles'. This is why there is a `src/L2/sova/` and not an `@sova-network/` import in the `L2Genesis.s.sol file` for the Sova contracts.

### Step 4
Deploy your OP chain.

> NOTE: Prior to running this next command, remember to remove any previous cached deployments with: `rm -rf ~/.cache/op-deployer`
```
op-deployer --cache-dir ~/.cache/op-deployer apply \
  --workdir ~/running-sova/config/testnet \
  --l1-rpc-url $L1_RPC_URL \
  --private-key $PRIVATE_KEY
```

### Step 5
Generate genesis files and chain information

```
op-deployer inspect genesis --workdir ~/running-sova/config/testnet 120893 > ~/running-sova/config/testnet/genesis.json
op-deployer inspect rollup --workdir ~/running-sova/config/testnet 120893 > ~/running-sova/config/testnet/rollup.json
```

### Step 6

Change `"interopTime"` in the genesis.json and rollup.json files from `0` to `null`. Without this change, the op-node will try to look for the interop config and also a op-supervisor connection.

### Automation

Run the script [here](/scripts/run-op-deployer.sh) to run all the op-deployer commands. Be sure to update the script `intent.toml` file and other config vars.

## Using optimism-package to deploy using op-deployer under the hood

Download the repo at [ethpandops/optimism-package](https://github.com/ethpandaops/optimism-package). This repo is a combination of the ethpandops/ethereum-package repo and the op-deployer tool.

This repo is basically a wrapper around ethereum-package where in the network_params.toml config you can specify `optimism_package` and `ethereum-package` sections.

Run the launcher with:
```bash
kurtosis run github.com/ethpandaops/optimism-package --args-file https://raw.githubusercontent.com/ethpandaops/optimism-package/main/network_params.yaml

# or

kurtosis run . --args-file ./network_params.yaml
```

To clean up running enclaves and data, you can run:

```shell
kurtosis clean -a
```

This will stop and remove all running enclaves and **delete all data**.

NOTES:
- If using in a production environment you must update this mneumonic priop to launching the chain. https://github.com/ethpandaops/optimism-package/blob/340765134e6bd6419dc9636a50f82d176b962468/static_files/scripts/fund.sh#L12
- REMINDER: There is a hardcoded owner address in the L2Genesis.s.sol script for setting the owner of the native BTC wrapper at launch
- Instead of reading from local forge-artifacts, you must used a host url that contains this data. To create this, we are using Github Releases for the hosting. The release is under the [op-deployer-v0.4.0-rc.2](https://github.com/SovaNetwork/optimism/tree/op-deployer-v0.4.0-rc.2) branch and under the release name `sova-op-deployer-v0.4.0-rc.2`. With this release you have access to this url: https://github.com/SovaNetwork/optimism/releases/download/sova-op-deployer-v0.4.0-rc.2/sova-bedrock-op-testnet-artifacts.tar.gz to use in the network_params.yaml file
  - To create this tarbell and the release for it like above use:
    ```bash
    cd packages/contracts-bedrock

    # always re-run all build commands prior to creating the release
    forge clean
    forge install
    forge build

    # create dedicated artifact folder
    mkdir sova-contract-artifacts

    # Copy required folders into it
    cp -r forge-artifacts cache artifacts/build-info sova-contract-artifacts/

    # Create the tarball
    cd sova-contract-artifacts
    tar -czvf ../sova-bedrock-op-testnet-artifacts.tar.gz .
    cd ..
    ```
  - Then upload sova-bedrock-op-testnet-artifacts.tar.gz to the appropriate release on GitHub under your desired tag (e.g. sova-op-deployer-v0.4.0-rc.2). Use the github UI to select the sova-bedrock-op-testnet-artifacts.tar.gz file for upload.

### Shortcuts

1. You can use the optimism-package to generate all admin keys for the network. The keys are generated [here](https://github.com/ethpandaops/optimism-package/blob/52ed3e6e8f1788adcac15baf4b65b408cf13961a/static_files/scripts/fund.sh#L12) in the code. Be sure to generate a new mnemoic other seed data.
2. You can use the op-deployer pipeline in the optimism-package to generate the intents.toml file.