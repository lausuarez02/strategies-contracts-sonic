const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Important Sonic mainnet addresses
    const VAULT_ADDRESS = "0x4BdE0740740b8dBb5f6Eb8c9ccB4Fc01171e953C";
    const WRAPPED_SONIC = "0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38";
    const SFC = "0xFC00FACE00000000000000000000000000000000";
    const VALIDATOR_ID = 16;
    const DEBRIDGE_EXCHANGE = "0x6352a56caadC4F1E25CD6c75970Fa768A3304e64";
    console.log("Using validator ID:", VALIDATOR_ID);

    // Arbitrum addresses
    const ARBITRUM_AAVE_POOL = "0x794a61358D6845594F94dc1DB02A252b5b4814aD";
    const ARBITRUM_DEBRIDGE = "0x43dE2d77BF8027e25dBD179B491e8d64f38398aA";
    const ARBITRUM_CHAIN_ID = 42161;
    const ARBITRUM_WETH = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";

    // Beefy USDC.e Silo vault address
    const BEEFY_USDC_VAULT = "0xdb6E5dC4C6748EcECb97b565F6C074f24384fD07" // Need the actual vault address from Beefy
    const USDC_ADDRESS = "0x29219dd400f2Bf60E5a23d13Be72B486D4038894";
    try {
        // Deploy Oracle first
        console.log("Deploying Price Oracle...");
        const PriceOracle = await ethers.getContractFactory("PriceOracle");
        const oracle = await PriceOracle.deploy();
        await oracle.waitForDeployment();
        const oracleAddress = await oracle.getAddress();
        console.log("PriceOracle deployed to:", oracleAddress);

        // Deploy Main Sonic-Beefy Strategy
        console.log("\nPreparing MainStrategy deployment with parameters:");
        console.log("Vault (deployer):", deployer.address);
        console.log("SFC:", SFC);
        console.log("WRAPPED_SONIC:", WRAPPED_SONIC);
        console.log("VALIDATOR_ID:", VALIDATOR_ID);
        console.log("BeefyVault:", BEEFY_USDC_VAULT);
        
        console.log("\nDeploying Main Sonic-Beefy Strategy...");
        const MainStrategy = await ethers.getContractFactory("SonicBeefyFarmStrategy");
        const mainStrategy = await MainStrategy.deploy(
            deployer.address,  // vault
            SFC,              // sfc
            WRAPPED_SONIC,    // wrappedSonic
            VALIDATOR_ID,     // defaultValidatorId
            BEEFY_USDC_VAULT, // beefyVault
            DEBRIDGE_EXCHANGE,
            USDC_ADDRESS
        );
        await mainStrategy.waitForDeployment();
        const mainStrategyAddress = await mainStrategy.getAddress();
        console.log("MainStrategy deployed to:", mainStrategyAddress);

        // Deploy Aave-Sonic-Beefy Strategy
        console.log("Deploying Aave-Sonic-Beefy Strategy...");
        const AaveStrategy = await ethers.getContractFactory("AaveSonicBeefyStrategy");
        const aaveStrategy = await AaveStrategy.deploy(
            deployer.address,
            ARBITRUM_WETH,
            ARBITRUM_AAVE_POOL,
            ARBITRUM_DEBRIDGE,
            BEEFY_USDC_VAULT,
            ARBITRUM_WETH,
            oracleAddress,
            ARBITRUM_CHAIN_ID,
            WRAPPED_SONIC
        );
        await aaveStrategy.waitForDeployment();
        const aaveStrategyAddress = await aaveStrategy.getAddress();
        console.log("AaveStrategy deployed to:", aaveStrategyAddress);

        // Set up price feeds in oracle
        console.log("Setting up price feeds...");
        await oracle.setFeed(
            ARBITRUM_WETH,
            "0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612"
        );

        console.log("\nDeployment Summary:");
        console.log("-------------------");
        console.log("PriceOracle:", oracleAddress);
        console.log("MainStrategy:", mainStrategyAddress);
        console.log("AaveStrategy:", aaveStrategyAddress);

        console.log("\nVerification commands:");
        console.log("----------------------");
        console.log(`npx hardhat verify --network mainnet ${oracleAddress}`);
        console.log(`npx hardhat verify --network mainnet ${mainStrategyAddress} ${deployer.address} ${SFC} ${WRAPPED_SONIC} ${VALIDATOR_ID} ${BEEFY_USDC_VAULT} ${DEBRIDGE_EXCHANGE}`);
        console.log(`npx hardhat verify --network mainnet ${aaveStrategyAddress} ${deployer.address} ${ARBITRUM_WETH} ${ARBITRUM_AAVE_POOL} ${ARBITRUM_DEBRIDGE} ${BEEFY_USDC_VAULT} ${ARBITRUM_WETH} ${oracleAddress} ${ARBITRUM_CHAIN_ID} ${WRAPPED_SONIC}`);

    } catch (error) {
        console.error("\nDeployment failed with error:", error.message);
        if (error.data) {
            console.error("Error data:", error.data);
        }
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 