

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.12",
};
task("compileandflatten", async () => {
  await hre.run("compile")
  await hre.run("flatten")
})