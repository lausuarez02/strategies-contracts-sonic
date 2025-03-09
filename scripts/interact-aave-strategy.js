const { ethers } = require("hardhat");

async function main() {
    const STRATEGY_ADDRESS = "0xa1057829b37d1b510785881B2E87cC87fb4cccD3";
    const WSONIC = "0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38";
    const DEPOSIT_AMOUNT = ethers.parseEther("1.0"); // 1 WSONIC

    // Get contract instances
    const strategy = await ethers.getContractAt("AaveSonicBeefyStrategy", STRATEGY_ADDRESS);
    const wsonicToken = await ethers.getContractAt("IERC20", WSONIC);
    
    try {
        const [signer] = await ethers.getSigners();
        
        // Check WSONIC balance first
        const balance = await wsonicToken.balanceOf(signer.address);
        console.log("Your WSONIC Balance:", ethers.formatEther(balance));

        // Approve strategy to spend WSONIC
        console.log("Approving WSONIC...");
        const approveTx = await wsonicToken.approve(STRATEGY_ADDRESS, DEPOSIT_AMOUNT);
        await approveTx.wait();
        console.log("Approved WSONIC");

        // Deposit into strategy
        console.log("Depositing WSONIC...");
        const depositTx = await strategy.deposit(WSONIC, DEPOSIT_AMOUNT);
        await depositTx.wait();
        console.log("Deposited", ethers.formatEther(DEPOSIT_AMOUNT), "WSONIC");

    } catch (error) {
        console.error("Error:", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 