# Config explained
Price is determined by ratio of "tokensForSale" and "ONEToRaise".
"maximumTokensperWallet" only applies if it is set to anything above 0.
"buyingStartsAt" along with "buyingEndsAt" are the dates and times of which users can purchase tokens.
"vestingStartsAt" and "vestingEndsAt" dictate the period of which tokens are linearly unlocked.
"timeToClaim" is a value added on to "vestingEndsAt" which protects users from owner retrieving tokens before they have the chance to claim them. This only applies if the owner has called "lockIn()" in the contract.
"newOwner" is the address to transfer ownership of the contract to once it is deployed. The deploy script will ask to confirm this.

# IDO explained
1. Contract deployed.
2. Date of buying is reached, allowing users to purchase tokens.
3. Ending date of buying is reached, preventing users to purchase tokens any longer.
4. Vesting date is reached, beginning a linear vestment of tokens.
5. Users can claim what they are owed as time passes.
6. Ending date of vesting is reached, ending the linear vestment of tokens.
