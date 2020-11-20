# Deploying TREE

## How to deploy TREE

### Stage 1

Stage 1 of deployment will deploy all of the contracts and burn the admin keys.

UniswapOracle will be left uninitialized after this stage, because initialization requires existing liquidity in the TREE-dai UNI-V2 pool.

The LP reward pool and the forests (initial distribution pools) will be activated at `rewardStartTimestamp` in `deploy-configs/mainnet.json`.

This stage is when the TREE initial distribution & price discovery happens. Rebasing is not enabled.

**Note**: Before you deploy anything, go through `deploy-configs/mainnet.json` and make sure the parameters are what you want, especially `charity`.

**Another note**: Ensure that `deploy-configs/network.json` has the correct network name (e.g. mainnet).

#### Command

```bash
npx buidler deploy --network [networkName] --tags stage1
```

### Stage 2

Stage 2 involves deploying the Aragon DAO on the L2 chain, which requires TREE being deployed. Do it, set `gov` in `deploy-configs/mainnet.json` to the L2 DAO address, and proceed. This would set the admin of the timelock contract to the DAO.

#### Command

```bash
npx buidler deploy --network [networkName] --tags stage2
```

### Stage 3

Stage 3 of deployment will initialize UniswapOracle. Before stage 2 there must be existing liquidity in the TREE-dai UNI-V2 pool.

Rebasing will be enabled 12 hours after UniswapOracle is initialized.

#### Command

```bash
npx buidler deploy --network [networkName] --tags stage3
```
