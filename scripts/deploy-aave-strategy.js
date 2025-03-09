const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Get contract factory
    const AaveSonicBeefyStrategy = await ethers.getContractFactory("AaveSonicBeefyStrategy");

    // Sonic Chain addresses
    const VAULT_ADDRESS = "0x4BdE0740740b8dBb5f6Eb8c9ccB4Fc01171e953C"; // Your SuperVault address
    const WSONIC = "0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38";        // Wrapped Sonic
    const BEEFY_VAULT = "0xdb6E5dC4C6748EcECb97b565F6C074f24384fD07";   // Beefy vault
    const USDC = "0x29219dd400f2Bf60E5a23d13Be72B486D4038894";          // USDC.e on Sonic

    // Arbitrum addresses
    const AAVE_POOL = "0x794a61358D6845594F94dc1DB02A252b5b4814aD";     // Aave v3 pool
    const ARB_USDC = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8";      // USDC on Arbitrum
    const DEBRIDGE = "0x43dE2d77BF8027e25dBD179B491e8d64f38398aA";      // DeBridge
    
    // Deploy strategy
    const strategy = await AaveSonicBeefyStrategy.deploy(
        VAULT_ADDRESS,
        AAVE_POOL,
        WSONIC,
        BEEFY_VAULT,
        USDC,
        ARB_USDC,
        DEBRIDGE
    );

    // Wait for deployment
    await strategy.waitForDeployment();
    console.log("AaveSonicBeefyStrategy deployed to:", await strategy.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 