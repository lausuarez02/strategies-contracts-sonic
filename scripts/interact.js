const { ethers } = require("hardhat");

async function main() {
    // Contract addresses from deployment
    const STRATEGY_ADDRESS = "0xC4012a3D99BC96637A03BF91A2e7361B1412FD17";
    const USDC_ADDRESS = "0xdb6E5dC4C6748EcECb97b565F6C074f24384fD07";
    
    // Connect to contracts
    const Strategy = await ethers.getContractFactory("SonicBeefyFarmStrategy");
    const strategy = await ethers.getContractAt("SonicBeefyFarmStrategy", STRATEGY_ADDRESS);
    const usdc = await ethers.getContractAt("IERC20", USDC_ADDRESS);
    
    // Get signer
    const [signer] = await ethers.getSigners();
    console.log("Interacting with contracts using address:", signer.address);

    // Check USDC balance
    const usdcBalance = await usdc.balanceOf(signer.address);
    console.log("\nInitial USDC Balance:", ethers.formatUnits(usdcBalance, 6));

    // Amount to deposit (1 USDC)
    const depositAmount = ethers.parseUnits("1", 6);
    
    try {
        // Approve USDC
        console.log("\nApproving USDC...");
        const approveTx = await usdc.approve(STRATEGY_ADDRESS, depositAmount);
        await approveTx.wait();
        console.log("USDC approved!");

        // Deposit
        console.log("\nDepositing 1 USDC...");
        const depositTx = await strategy.deposit(USDC_ADDRESS, depositAmount);
        await depositTx.wait();
        console.log("Deposit successful!");

        // Check shares balance
        const shares = await strategy.balanceOf(signer.address);
        console.log("\nShares received:", ethers.formatUnits(shares, 18));

        // Check new USDC balance
        const newUsdcBalance = await usdc.balanceOf(signer.address);
        console.log("New USDC Balance:", ethers.formatUnits(newUsdcBalance, 6));

    } catch (error) {
        console.error("Error:", error.message);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 