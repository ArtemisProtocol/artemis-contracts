const prompt = require("prompt-sync")()
let {token, tokensForSale, collateralToken, collateralRequired, ONEToRaise, buyingStartsAt, buyingEndsAt, vestingStartsAt, vestingEndsAt, timeToClaim, maximumTokensPerWallet, newOwner} = require("./config")

buyingStartsAt = Math.round(new Date(buyingStartsAt).getTime() / 1000)
buyingEndsAt = Math.round(new Date(buyingEndsAt).getTime() / 1000)
vestingStartsAt = Math.round(new Date(vestingStartsAt).getTime() / 1000)
vestingEndsAt = Math.round(new Date(vestingEndsAt).getTime() / 1000)


async function main() {

  const IDO = await hre.ethers.getContractFactory("IDO");
  const ido = await IDO.deploy(token, tokensForSale, collateralToken, collateralRequired, ONEToRaise, buyingStartsAt, buyingEndsAt, vestingStartsAt, vestingEndsAt, timeToClaim, maximumTokensPerWallet);

  await ido.deployed();

  console.log("IDO contract deployed to:", ido.address);

  const changeOwner = await prompt(`Would you like to transfer ownership to address ${newOwner} as specified in the config? Press enter to ignore: `)

  if(changeOwner.length > 0) {
      await ido.transferOwnership(newOwner)
      console.log("Ownership transferred.")
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
