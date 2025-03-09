const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Get contract factory
    const MainStrategy = await ethers.getContractFactory("SonicBeefyFarmStrategy");

    // Important Sonic mainnet addresses
    const VAULT_ADDRESS = "0x4BdE0740740b8dBb5f6Eb8c9ccB4Fc01171e953C"; // SuperVault
    const WRAPPED_SONIC = "0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38";
    const SFC = "0xFC00FACE00000000000000000000000000000000";
    const VALIDATOR_ID = 16;
    const BEEFY_VAULT = "0xdb6E5dC4C6748EcECb97b565F6C074f24384fD07";
    const USDC = "0x29219dd400f2Bf60E5a23d13Be72B486D4038894";
    const DEBRIDGE = "0x6352a56caadC4F1E25CD6c75970Fa768A3304e64";
    
    console.log("Using validator ID:", VALIDATOR_ID);

    // Deploy strategy
    const strategy = await MainStrategy.deploy(
        VAULT_ADDRESS,
        SFC,
        WRAPPED_SONIC,
        VALIDATOR_ID,
        BEEFY_VAULT,
        USDC,
        DEBRIDGE
    );

    // Wait for deployment
    await strategy.waitForDeployment();
    console.log("MainStrategy deployed to:", await strategy.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });