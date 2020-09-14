# TREE

Elastic supply currency for funding charity and public goods.

## TREE overview

### Rebase

When the price of 1 TREE exceeds 1.05 yUSD, a rebase will be triggered, minting TREE proportional to the price deviation. Unlike Ampleforth and Yam, TREE does not have negative rebases when the price drops below 1 yUSD.

Of the minted TREE, 10% is sent to a rewards pool for TREE-yUSD UNI-V2 liquidity providers, 10% is sent to charity, and 80% is sold for yUSD and put into the reserve. These weights can be changed by governance, though a hardcoded range is set.

### The reserve & quadratic burning

TREE generates upwards price pressure using the reserve. The reserve holds the yUSD earned from rebases, and TREE holders can burn their TREEs to receive part of the reserve.

Rather than proportional-share burning (i.e. burn x% of supply to get x% of reserve), TREE uses **quadratic burning**, where for instance if you burnt 10% of the TREE supply, you get `10% * 10% = 1%` of the reserve.

Quadratic burning creates an interesting game where TREE holders are incentivized to continue holding, in anticipation of other holders burning first and increasing the value of TREE. Let's look at an example: say Alice owns 50% of all TREE, and Bob owns the other 50%. If Alice burnt all of her TREE, she would get `50% * 50% = 25%` of the reserve, and Bob, who now holds 100% of the TREE supply, would get the remaining 75%. As you can see, whoever burns **last** gets the most value from their TREEs, and whoever burns first actually loses out.

(You can picture this as if you burnt your TREEs, its ashes would act as nutrients and make the remaining trees grow taller :D)

Of course, this does not mean that nobody will ever burn their TREE: when the market price of TREE goes below the price you can burn TREE at, you can generate a profit through arbitrage (buying TREE on the market and burning them). When someone performs this arbitrage, not only would TREE's price increase due to the decreased supply, it would also increase because you can now get more yUSD from burning TREE.

Quadratic burning efficiently uses the reserve to maintain an upwards price pressure, incentivizes long-term holding, and protects holders against dump-happy whales.

### The TREE DAO

The charity TREEs generated during rebases will be sent to an Aragon DAO that uses [Conviction Voting](https://medium.com/giveth/conviction-voting-a-novel-continuous-decision-making-alternative-to-governance-aa746cfb9475) to make decisions on which charities to fund and how much to fund. TREE will be used as the governance token.

The Aragon DAO will also have regular 1-token-1-vote voting for changing the system parameters of TREE (e.g. the weights for distributing minted TREEs), which should be used far less frequently.

## Local development

### Prerequisites

Clone the repo, and run `npm install` in the repo directory.

### Compile

`npx buidler compile`

### Testing

In one terminal, run `scripts/start-mainnet-fork.sh`. Then in another terminal, run `npx buidler test --network ganache`.

The first test will take a few minutes to run, because it needs to deploy the contracts.

### Deploy local test environment

In one terminal, run `scripts/start-mainnet-fork.sh`. Then in another terminal, run `scripts/setup-test-env.js`. This will set up a local environment that you can use for things like testing the frontend.

### Deployment

Read [DEPLOY_README.md](DEPLOY_README.md)
