const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Important Sonic mainnet addresses
    const WRAPPED_SONIC = "0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38"; // Need Wrapped Sonic token address
    const SFC = "0x0000000000000000000000000000000000000000"; // Need Sonic Foundation Contract address
    const VALIDATOR_ID = 1; // Need your validator ID
    const AAVE_POOL = "0x0000000000000000000000000000000000000000"; // Need Aave pool on Sonic
    const DEBRIDGE = "0x0000000000000000000000000000000000000000"; // Need deBridge gateway on Sonic
    const DESTINATION_CHAIN_ID = 1; // The chain ID you want to bridge to
    const DESTINATION_TOKEN = "0x0000000000000000000000000000000000000000"; // Token address on destination chain

    // Deploy Oracle first
    console.log("Deploying Price Oracle...");
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    const oracle = await PriceOracle.deploy();
    await oracle.waitForDeployment();
    console.log("PriceOracle deployed to:", await oracle.getAddress());

    // Deploy Mock Tokens (for testing)
    console.log("Deploying Mock Tokens...");
    const MockToken = await ethers.getContractFactory("MockERC20");
    const mockToken = await MockToken.deploy("Mock Token", "MTK");
    await mockToken.waitForDeployment();
    console.log("MockToken deployed to:", await mockToken.getAddress());

    // Deploy Beefy Vault and Strategy
    console.log("Deploying Beefy components...");
    const MockBeefy = await ethers.getContractFactory("MockBeefyVault");
    const beefyVault = await MockBeefy.deploy(await mockToken.getAddress());
    await beefyVault.waitForDeployment();
    console.log("BeefyVault deployed to:", await beefyVault.getAddress());

    // Deploy Main Sonic-Beefy Strategy
    console.log("Deploying Main Sonic-Beefy Strategy...");
    const MainStrategy = await ethers.getContractFactory("SonicBeefyFarmStrategy");
    const mainStrategy = await MainStrategy.deploy(
        deployer.address, // vault address - you'll need to update this
        SFC,             // Sonic Foundation Contract
        WRAPPED_SONIC,   // Wrapped Sonic token
        VALIDATOR_ID,    // Your validator ID
        "" // Beefy vault - you'll need this address
    );
    await mainStrategy.waitForDeployment();
    console.log("MainStrategy deployed to:", await mainStrategy.getAddress());

    // Deploy Aave-Sonic-Beefy Strategy
    console.log("Deploying Aave-Sonic-Beefy Strategy...");
    const AaveStrategy = await ethers.getContractFactory("AaveSonicBeefyStrategy");
    const aaveStrategy = await AaveStrategy.deploy(
        deployer.address, // vault - you'll need to update this
        WRAPPED_SONIC,   // want token (Wrapped Sonic)
        AAVE_POOL,      // Aave pool
        DEBRIDGE,       // deBridge gateway
        "", // Beefy vault - you'll need this address
        WRAPPED_SONIC,   // wrapped native (Wrapped Sonic again)
        await oracle.getAddress(), // price oracle we just deployed
        DESTINATION_CHAIN_ID,
        DESTINATION_TOKEN
    );
    await aaveStrategy.waitForDeployment();
    console.log("AaveStrategy deployed to:", await aaveStrategy.getAddress());

    // Set up price feeds in oracle
    console.log("Setting up price feeds...");
    await oracle.setFeed(
        WRAPPED_SONIC,
        "" // You'll need the Chainlink price feed address for Sonic
    );

    console.log("\nDeployment Summary:");
    console.log("-------------------");
    console.log("PriceOracle:", await oracle.getAddress());
    console.log("MockToken:", await mockToken.getAddress());
    console.log("BeefyVault:", await beefyVault.getAddress());
    console.log("MainStrategy:", await mainStrategy.getAddress());
    console.log("AaveStrategy:", await aaveStrategy.getAddress());

    console.log("\nVerification commands:");
    console.log("----------------------");
    console.log(`npx hardhat verify --network mainnet ${await oracle.getAddress()}`);
    
    console.log(`npx hardhat verify --network mainnet ${await mainStrategy.getAddress()} ${deployer.address} ${SFC} ${WRAPPED_SONIC} ${VALIDATOR_ID} BEEFY_VAULT_ADDRESS`);
    
    console.log(`npx hardhat verify --network mainnet ${await aaveStrategy.getAddress()} ${deployer.address} ${WRAPPED_SONIC} ${AAVE_POOL} ${DEBRIDGE} BEEFY_VAULT_ADDRESS ${WRAPPED_SONIC} ${await oracle.getAddress()} ${DESTINATION_CHAIN_ID} ${DESTINATION_TOKEN}`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 