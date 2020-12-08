# VALUE IOU (mvUSD Bond)

### Summary

The ValueDefi MultiStables vault was recently the subject of a complex attack that resulted in a loss of user deposits.

We create a compensation fund which will be funded by a combination of the dev fund, insurance fund and a portion of the fees that are currently generated by the protocol.

To make the accounting part for affected users as seamless as possible, an IOU token will be created at a 1:1 ratio for every dollar lost by affected farmers at the MultiStables vault with some enhancements. It will auto accrue 10% APY using rebase tech every week. That means if you hold 1 IOU token, next week you will have approximately 1.0019 IOU token automatically. The compensation fund will be used to buy back all IOU tokens to remain the peg of 1$ and burn all the bought IOU tokens and until such a time when the compensation fund exceeds the remaining outstanding IOU tokens.

This IOU token has built-in inflation and this compensates users for lack of access to capital. It also allows the market to possibly buy and sell the ious, giving those depositors the ability to exit early, possibly at a gross profit or at a discount. If the price is too high, then speculators will absorb losses.

Full details: https://valuedefi.medium.com/multistables-vault-exploit-post-mortem-d11b0635788f

### Token Info
- Name: `mvStablesBond`
- Symbol: `mvUSDBond`
- Decimals: `18`
- Initial Supply: `6,800,000` (6,700,000 for reimbursenment and 100,000 for initial liquidity on Value Liquid FaasPool)

### Run Tests

```
git clone https://github.com/valuedefi/value-iou
cd value-iou
yarn build
yarn test
```