const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AaveSonicBeefyStrategy", function () {
    let strategy, vault, owner, manager;
    let want, aavePool, deBridge, beefyVault, wrappedNative, priceOracle;
    let destToken;
    const DESTINATION_CHAIN_ID = 137;
    const INITIAL_DEPOSIT = ethers.parseEther("100");

    beforeEach(async function () {
        [owner, manager, vault] = await ethers.getSigners();

        // Deploy mock tokens
        const MockToken = await ethers.getContractFactory("MockERC20");
        want = await MockToken.deploy("Want Token", "WANT");
        destToken = await MockToken.deploy("Dest Token", "DEST");

        // Deploy mocks
        const MockAavePool = await ethers.getContractFactory("MockAavePool");
        aavePool = await MockAavePool.deploy();

        const MockDeBridge = await ethers.getContractFactory("MockDeBridgeGateway");
        deBridge = await MockDeBridge.deploy();

        const MockBeefyVault = await ethers.getContractFactory("MockBeefyVault");
        beefyVault = await MockBeefyVault.deploy(want.target);

        const MockWrappedNative = await ethers.getContractFactory("MockWrappedNative");
        wrappedNative = await MockWrappedNative.deploy();

        const MockOracle = await ethers.getContractFactory("MockOracle");
        priceOracle = await MockOracle.deploy();

        // Deploy strategy
        const Strategy = await ethers.getContractFactory("AaveSonicBeefyStrategy");
        strategy = await Strategy.deploy(
            vault.address,
            want.target,
            aavePool.target,
            deBridge.target,
            beefyVault.target,
            wrappedNative.target,
            priceOracle.target,
            DESTINATION_CHAIN_ID,
            destToken.target
        );

        // Setup roles
        await strategy.grantRole(await strategy.DEFAULT_ADMIN_ROLE(), owner.address);
        await strategy.grantRole(await strategy.VAULT_ROLE(), vault.address);
        await strategy.grantRole(await strategy.MANAGER_ROLE(), manager.address);

        // Setup initial balances and approvals
        await want.mint(vault.address, INITIAL_DEPOSIT);
        await want.connect(vault).approve(strategy.target, ethers.MaxUint256);
        await want.mint(aavePool.target, INITIAL_DEPOSIT * 10n);

        // Approve strategy to spend tokens
        await want.connect(vault).approve(aavePool.target, ethers.MaxUint256);
        await want.connect(vault).approve(deBridge.target, ethers.MaxUint256);
    });

    describe("Initialization", function () {
        it("Should set correct initial values", async function () {
            expect(await strategy.vault()).to.equal(vault.address);
            expect(await strategy.want()).to.equal(want.target);
            expect(await strategy.aavePool()).to.equal(aavePool.target);
            expect(await strategy.deBridge()).to.equal(deBridge.target);
            expect(await strategy.beefyVault()).to.equal(beefyVault.target);
            expect(await strategy.destinationChainId()).to.equal(DESTINATION_CHAIN_ID);
        });

        it("Should set correct roles", async function () {
            expect(await strategy.hasRole(await strategy.VAULT_ROLE(), vault.address)).to.be.true;
            expect(await strategy.hasRole(await strategy.MANAGER_ROLE(), manager.address)).to.be.true;
        });
    });

    describe("Core Operations", function () {
        beforeEach(async function () {
            await priceOracle.setPrice(want.target, ethers.parseEther("1"));
            await want.connect(vault).transfer(strategy.target, INITIAL_DEPOSIT);
            
            // Add approval for AavePool to spend strategy's tokens
            await want.approve(aavePool.target, ethers.MaxUint256);
        });

        it("Should deposit and supply to Aave", async function () {
            await expect(strategy.connect(vault).deposit())
                .to.emit(strategy, "Supplied")
                .withArgs(INITIAL_DEPOSIT);
        });

        it("Should borrow and bridge", async function () {
            console.log("\nInitial State:");
            console.log("Strategy address:", strategy.target);
            console.log("AavePool address:", aavePool.target);
            console.log("Initial want balance:", await want.balanceOf(strategy.target));
            console.log("Initial want balance of AavePool:", await want.balanceOf(aavePool.target));
            
            console.log("\nPre-deposit State:");
            console.log("Pre-deposit supplies:", await aavePool.supplies(strategy.target));
            console.log("Pre-deposit borrows:", await aavePool.borrows(strategy.target));
            
            // Call deposit and get transaction receipt for event analysis
            const tx = await strategy.connect(vault).deposit();
            const receipt = await tx.wait();
            
            console.log("\nTransaction events:");
            for (const event of receipt.logs) {
                try {
                    console.log("Event:", event);
                } catch (e) {
                    console.log("Raw event:", event);
                }
            }
            
            console.log("\nPost-deposit State:");
            const borrowed = await strategy.totalBorrowed();
            console.log("Total borrowed:", borrowed);
            console.log("Want balance after:", await want.balanceOf(strategy.target));
            console.log("Want balance of AavePool after:", await want.balanceOf(aavePool.target));
            console.log("AavePool supplies:", await aavePool.supplies(strategy.target));
            console.log("AavePool borrows:", await aavePool.borrows(strategy.target));
            
            // Log all AavePool events
            const borrowEvents = await aavePool.queryFilter(aavePool.filters.Borrowed());
            console.log("\nBorrow events:", borrowEvents);
            
            const expectedBorrow = (INITIAL_DEPOSIT * 7500n) / 10000n;
            console.log("Expected borrow:", expectedBorrow);
            
            expect(borrowed).to.equal(expectedBorrow);
        });

        it("Should respect min/max bridge amounts", async function () {
            await strategy.connect(manager).setTokenInfo(
                DESTINATION_CHAIN_ID,
                want.target,
                destToken.target,
                ethers.parseEther("50"),
                ethers.parseEther("60")
            );

            await expect(strategy.connect(vault).deposit())
                .to.be.revertedWith("Amount too high");
        });

        it("Should track prices correctly", async function () {
            const price = ethers.parseEther("2");
            await priceOracle.setPrice(want.target, price);
            
            await expect(strategy.connect(vault).deposit())
                .to.emit(strategy, "BridgedToDestination")
                .withArgs(
                    (INITIAL_DEPOSIT * 7500n) / 10000n,
                    DESTINATION_CHAIN_ID,
                    price,
                    destToken.target
                );
        });
    });

    describe("Withdrawals", function () {
        beforeEach(async function () {
            await priceOracle.setPrice(want.target, ethers.parseEther("1"));
            await want.connect(vault).transfer(strategy.target, INITIAL_DEPOSIT);
            await strategy.connect(vault).deposit();
        });

        it("Should withdraw correctly", async function () {
            // Log balances before withdrawal
            console.log("\nBefore withdrawal:");
            console.log("Strategy want balance:", await want.balanceOf(strategy.target));
            console.log("AavePool want balance:", await want.balanceOf(aavePool.target));
            console.log("Strategy total supplied:", await strategy.totalSupplied());
            console.log("Strategy total borrowed:", await strategy.totalBorrowed());
            console.log("AavePool supplies:", await aavePool.supplies(strategy.target));
            console.log("AavePool borrows:", await aavePool.borrows(strategy.target));

            // First mint tokens to strategy for repayment
            const borrowedAmount = await strategy.totalBorrowed();
            await want.mint(strategy.target, borrowedAmount);
            console.log("\nAfter minting repayment tokens:");
            console.log("Strategy want balance:", await want.balanceOf(strategy.target));

            // Try to withdraw
            const withdrawAmount = INITIAL_DEPOSIT;
            console.log("\nTrying to withdraw:", withdrawAmount.toString());
            
            // Make sure AavePool has enough tokens for withdrawal
            await want.mint(aavePool.target, withdrawAmount);
            console.log("AavePool balance after mint:", await want.balanceOf(aavePool.target));

            await strategy.connect(vault).withdraw(withdrawAmount);

            // Log balances after withdrawal
            console.log("\nAfter withdrawal:");
            console.log("Strategy want balance:", await want.balanceOf(strategy.target));
            console.log("AavePool want balance:", await want.balanceOf(aavePool.target));
            console.log("Strategy total supplied:", await strategy.totalSupplied());
            console.log("Strategy total borrowed:", await strategy.totalBorrowed());
        });

        it("Should maintain health factor during withdrawal", async function () {
            await strategy.connect(vault).deposit();
            await aavePool.setHealthFactor(ethers.parseEther("0.9"));
            
            await expect(strategy.connect(vault).beforeDeposit())
                .to.be.revertedWith("Unhealthy position");
        });
    });

    describe("Admin Operations", function () {
        it("Should update token info", async function () {
            await strategy.connect(manager).setTokenInfo(
                DESTINATION_CHAIN_ID,
                want.target,
                destToken.target,
                ethers.parseEther("10"),
                ethers.parseEther("1000")
            );

            const tokenInfo = await strategy.chainTokens(DESTINATION_CHAIN_ID);
            expect(tokenInfo.sourceToken).to.equal(want.target);
            expect(tokenInfo.destToken).to.equal(destToken.target);
        });

        it("Should fail if non-manager tries to update token info", async function () {
            await expect(
                strategy.connect(vault).setTokenInfo(
                    DESTINATION_CHAIN_ID,
                    want.target,
                    destToken.target,
                    ethers.parseEther("10"),
                    ethers.parseEther("1000")
                )
            ).to.be.revertedWith(/AccessControl/);
        });
    });
}); 