# StormSafe
Created by Mark NAGI, 2023 All right reserved 
## This smart contract contains the following main functions:
- `checkUpkeep`: Checks whether the contract should perform upkeep and returns a boolean value indicating whether or not to do so.
- `performUpkeep`: Performs the upkeep by updating all NFT metadata and retrieving the temperature for one of the five eligible cities in an iterative approach.
- `buildMetadata`: Builds the metadata for an NFT by returning Source64 code that can be converted back to JSON format.
- `update_nfts`: Updates the temperature data for the NFTs.
- `requestTempData`: Requests temperature data from the Weather API.
- `fulfill`: Assigns the temperature variable to the return value of the API request.
- `mint4me`: Mints an NFT for the specified city and tier.
- `giveEquity`: Gives fake ETH to the message sender.
- `verifyContractDuration`: Verifies that the contract is still valid.
- `verifyThreshold`: Verifies that the temperature threshold has been reached.
- `giveClaim`: Checks if the temperature threshold conditions are met, and pays the message sender the claim amount.
