// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBase } from "../contracts/TestBase.sol";

import { Address, console } from "../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../modules/loan/contracts/MapleLoan.sol";

contract RequestRedeemTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);
    }

    function test_requestRedeem() external {
        depositLiquidity({
            lp:        lp,
            liquidity: 1_000e6
        });

        vm.startPrank(lp);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_000e6);

        assertEq(pool.totalSupply(), 1_000e6);
        assertEq(pool.balanceOf(lp), 1_000e6);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);

        uint256 shares = pool.requestRedeem(1_000e6);

        assertEq(shares, 1_000e6);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_000e6);

        assertEq(pool.totalSupply(), 1_000e6);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 1_000e6);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);
    }

    function testFuzz_requestRedeem(uint256 depositAmount, uint256 redeemAmount) external {
        depositAmount = constrictToRange(depositAmount, 1, 1e30);
        redeemAmount  = constrictToRange(redeemAmount,  1, depositAmount);

        depositLiquidity({
            lp:        lp,
            liquidity: depositAmount
        });

        vm.startPrank(lp);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);

        uint256 assets = pool.requestRedeem(redeemAmount);

        assertEq(assets, redeemAmount);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount - redeemAmount);
        assertEq(pool.balanceOf(wm), redeemAmount);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    redeemAmount);
        assertEq(withdrawalManager.totalCycleShares(3), redeemAmount);
    }

}

contract RedeemTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);
    }

    function test_redeem_singleUser_fullLiquidity_oneToOne() external {
        depositLiquidity({
            lp:        lp,
            liquidity: 1_000e6
        });

        vm.startPrank(lp);

        pool.requestRedeem(1_000e6);

        vm.warp(start + 2 weeks);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_000e6);

        assertEq(pool.totalSupply(), 1_000e6);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 1_000e6);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);

        uint256 assets = pool.redeem(1_000e6, lp, lp);

        assertEq(assets, 1_000e6);

        assertEq(fundsAsset.balanceOf(address(lp)),   1_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.totalSupply(), 0);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
    }

    function testFuzz_redeem_singleUser_fullLiquidity_oneToOne(uint256 depositAmount, uint256 redeemAmount) external {
        depositAmount = constrictToRange(depositAmount, 1, 1e30);
        redeemAmount  = constrictToRange(redeemAmount,  1, depositAmount);

        depositLiquidity({
            lp:        lp,
            liquidity: depositAmount
        });

        vm.startPrank(lp);

        pool.requestRedeem(redeemAmount);

        vm.warp(start + 2 weeks);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), depositAmount);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount - redeemAmount);
        assertEq(pool.balanceOf(wm), redeemAmount);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    redeemAmount);
        assertEq(withdrawalManager.totalCycleShares(3), redeemAmount);

        uint256 assets = pool.redeem(redeemAmount, lp, lp);

        assertEq(assets, redeemAmount);

        assertEq(fundsAsset.balanceOf(address(lp)),   redeemAmount);
        assertEq(fundsAsset.balanceOf(address(pool)), depositAmount - redeemAmount);

        assertEq(pool.totalSupply(), depositAmount - redeemAmount);
        assertEq(pool.balanceOf(lp), depositAmount - redeemAmount);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
    }

    function test_redeem_singleUser_fullLiquidity_fullRedeem() external {
        depositLiquidity({
            lp:        lp,
            liquidity: 1_000e6
        });

        // Transfer cash into pool to increase totalAssets
        fundsAsset.mint(address(pool), 250e6);

        vm.startPrank(lp);

        pool.requestRedeem(1_000e6);

        vm.warp(start + 2 weeks);

        assertEq(fundsAsset.balanceOf(address(lp)),   0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1_250e6);

        assertEq(pool.totalSupply(), 1_000e6);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 1_000e6);

        assertEq(withdrawalManager.exitCycleId(lp),     3);
        assertEq(withdrawalManager.lockedShares(lp),    1_000e6);
        assertEq(withdrawalManager.totalCycleShares(3), 1_000e6);

        uint256 assets = pool.redeem(1_000e6, lp, lp);

        assertEq(assets, 1_250e6);

        assertEq(fundsAsset.balanceOf(address(lp)),   1_250e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(pool.totalSupply(), 0);
        assertEq(pool.balanceOf(lp), 0);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
    }

}

contract MultiUserRedeemTests is TestBase {

    uint256 constant ROUND_MONTH = 365 days / 12;

    address borrower;
    address lp1;
    address lp2;
    address lp3;
    address wm;

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _createPool(ROUND_MONTH / 2, 2 days);  // Set interval to give round numbers
        _openPool();

        start = block.timestamp;

        borrower = address(new Address());
        lp1      = address(new Address());
        lp2      = address(new Address());
        lp3      = address(new Address());

        wm = address(withdrawalManager);

        // NOTE: Available liquidity ratio (AVR) = availableCash / totalRequestedLiquidity
        // Remaining shares = requestedShares * (1 - AVR)
    }

    function test_redeem_partialLiquidity_sameCash_sameExchangeRate() external {
        depositLiquidity(lp1, 1_000_000e6);
        depositLiquidity(lp2, 4_000_000e6);
        depositLiquidity(lp3, 5_000_000e6);

        fundAndDrawdownLoan({
            borrower:         borrower,
            amounts:          [uint256(5_000_000e6), uint256(5_000_000e6), 0],  // Pool will be at 50% liquidity
            interestRate:     0.12e18,
            paymentInterval:  ROUND_MONTH,
            numberOfPayments: 3
        });

        requestRedeem(lp1, 1_000_000e6);
        requestRedeem(lp2, 4_000_000e6);
        requestRedeem(lp3, 5_000_000e6);

        vm.warp(start + ROUND_MONTH);

        assertEq(pool.totalAssets(), 10_050_000e6 - 1);  // Exchange rate is 1.005 with rounding error

        assertEq(withdrawalManager.lockedShares(lp1), 1_000_000e6);
        assertEq(withdrawalManager.lockedShares(lp2), 4_000_000e6);
        assertEq(withdrawalManager.lockedShares(lp3), 5_000_000e6);

        assertEq(withdrawalManager.exitCycleId(lp1), 3);
        assertEq(withdrawalManager.exitCycleId(lp2), 3);
        assertEq(withdrawalManager.exitCycleId(lp3), 3);

        assertEq(withdrawalManager.totalCycleShares(3), 10_000_000e6);
        assertEq(withdrawalManager.totalCycleShares(4), 0);

        redeem(lp1, 1_000_000e6);

        // AVR = 5m / (10m * 1.005) => 1m * (1 - AVR) = 502_487_562190
        uint256 remainingShares1 = 1_000_000e6 - uint256(1_000_000e6) * 5_000_000e6 / (10_050_000e6 - 1);

        assertEq(remainingShares1, 502_487_562190);

        assertEq(withdrawalManager.lockedShares(lp1),   remainingShares1);
        assertEq(withdrawalManager.totalCycleShares(3), 9_000_000_000000);
        assertEq(withdrawalManager.totalCycleShares(4), remainingShares1);

        redeem(lp2, 4_000_000e6);

        // AVR = 4.5m / (9m * 1.005) (SAME) => 4m * (1 - AVR) = 2_009_950_248756
        uint256 remainingShares2 = 4_000_000e6 - uint256(4_000_000e6) * (4_500_000e6 + 1) / (9_045_000e6 - 1);

        assertEq(remainingShares2, 2_009_950_248756);

        assertEq(withdrawalManager.lockedShares(lp2),   remainingShares2);
        assertEq(withdrawalManager.totalCycleShares(3), 5_000_000_000000);
        assertEq(withdrawalManager.totalCycleShares(4), remainingShares1 + remainingShares2);  // LP1 + LP2 remaining shares

        redeem(lp3, 5_000_000e6);

        // AVR = 2.5m / (5m * 1.005) (SAME) => 4m * (1 - AVR) = 2_009_950_248760
        uint256 remainingShares3 = 5_000_000e6 - uint256(5_000_000e6) * (2_500_000e6 + 1) / (5_025_000e6 - 1);

        assertEq(remainingShares3, 2_512_437_810944);

        assertEq(withdrawalManager.lockedShares(lp3),   remainingShares3);  // AVR = 2.5m / (5m * 1.005) (SAME) => 4m * (1 - AVR) = 2_009_950_248760
        assertEq(withdrawalManager.totalCycleShares(3), 0);
        assertEq(withdrawalManager.totalCycleShares(4), remainingShares1 + remainingShares2 + remainingShares3);

        assertEq(pool.balanceOf(wm), remainingShares1 + remainingShares2 + remainingShares3);
        assertEq(pool.balanceOf(wm), 5_024_875_621890);  // Available liquidity ratio: 5m / (10m * 1.01) = 0.495049505 => 5m * (1 - 0.495049505) = remaining shares

        assertEq(fundsAsset.balanceOf(lp1), 500_000e6 - 1);  // Rounding error
        assertEq(fundsAsset.balanceOf(lp2), 2_000_000e6);
        assertEq(fundsAsset.balanceOf(lp3), 2_500_000e6 + 1);  // Rounding error
    }

    function test_redeem_partialLiquidity_sameCash_sameExchangeRate_exposeRounding() external {
        address lp4  = address(new Address());
        address lp5  = address(new Address());
        address lp6  = address(new Address());
        address lp7  = address(new Address());
        address lp8  = address(new Address());
        address lp9  = address(new Address());
        address lp10 = address(new Address());

        depositLiquidity(lp1,  1_000_000e6);
        depositLiquidity(lp2,  1_000_000e6);
        depositLiquidity(lp3,  1_000_000e6);
        depositLiquidity(lp4,  1_000_000e6);
        depositLiquidity(lp5,  1_000_000e6);
        depositLiquidity(lp6,  1_000_000e6);
        depositLiquidity(lp7,  1_000_000e6);
        depositLiquidity(lp8,  1_000_000e6);
        depositLiquidity(lp9,  1_000_000e6);
        depositLiquidity(lp10, 1_000_000e6);

        fundAndDrawdownLoan({
            borrower:         borrower,
            amounts:          [uint256(5_000_000e6), uint256(5_000_000e6), 0],
            interestRate:     0.12e18,
            paymentInterval:  ROUND_MONTH,
            numberOfPayments: 3
        });

        requestRedeem(lp1,  1_000_000e6);
        requestRedeem(lp2,  1_000_000e6);
        requestRedeem(lp3,  1_000_000e6);
        requestRedeem(lp4,  1_000_000e6);
        requestRedeem(lp5,  1_000_000e6);
        requestRedeem(lp6,  1_000_000e6);
        requestRedeem(lp7,  1_000_000e6);
        requestRedeem(lp8,  1_000_000e6);
        requestRedeem(lp9,  1_000_000e6);
        requestRedeem(lp10, 1_000_000e6);

        vm.warp(start + ROUND_MONTH);

        redeem(lp1,  1_000_000e6);
        redeem(lp2,  1_000_000e6);
        redeem(lp3,  1_000_000e6);
        redeem(lp4,  1_000_000e6);
        redeem(lp5,  1_000_000e6);
        redeem(lp6,  1_000_000e6);
        redeem(lp7,  1_000_000e6);
        redeem(lp8,  1_000_000e6);
        redeem(lp9,  1_000_000e6);
        redeem(lp10, 1_000_000e6);

        // Available liquidity ratio (AVR) = availableCash / totalRequestedLiquidity
        // Remaining shares = requestedShares * (1 - AVR)
        uint256 remainingShares = 1_000_000e6 - uint256(1_000_000e6) * 5_000_000e6 / (10_050_000e6 - 1);

        assertEq(remainingShares, 502_487_562190);

        assertEq(withdrawalManager.lockedShares(lp1),  remainingShares);
        assertEq(withdrawalManager.lockedShares(lp2),  remainingShares - 1);
        assertEq(withdrawalManager.lockedShares(lp3),  remainingShares - 1);
        assertEq(withdrawalManager.lockedShares(lp4),  remainingShares - 1);
        assertEq(withdrawalManager.lockedShares(lp5),  remainingShares - 1);
        assertEq(withdrawalManager.lockedShares(lp6),  remainingShares - 1);
        assertEq(withdrawalManager.lockedShares(lp7),  remainingShares - 1);
        assertEq(withdrawalManager.lockedShares(lp8),  remainingShares - 1);
        assertEq(withdrawalManager.lockedShares(lp9),  remainingShares - 1);
        assertEq(withdrawalManager.lockedShares(lp10), remainingShares - 2);

        assertEq(fundsAsset.balanceOf(lp1),  500_000e6 - 1);
        assertEq(fundsAsset.balanceOf(lp2),  500_000e6);
        assertEq(fundsAsset.balanceOf(lp3),  500_000e6);
        assertEq(fundsAsset.balanceOf(lp4),  500_000e6);
        assertEq(fundsAsset.balanceOf(lp5),  500_000e6);
        assertEq(fundsAsset.balanceOf(lp6),  500_000e6);
        assertEq(fundsAsset.balanceOf(lp7),  500_000e6);
        assertEq(fundsAsset.balanceOf(lp8),  500_000e6);
        assertEq(fundsAsset.balanceOf(lp9),  500_000e6);
        assertEq(fundsAsset.balanceOf(lp10), 500_000e6 + 1);
    }

    function test_redeem_partialLiquidity_sameCash_differentExchangeRate() external {
        depositLiquidity(lp1, 1_000_000e6);
        depositLiquidity(lp2, 4_000_000e6);
        depositLiquidity(lp3, 5_000_000e6);

        fundAndDrawdownLoan({
            borrower:         borrower,
            amounts:          [uint256(5_000_000e6), uint256(5_000_000e6), 0],
            interestRate:     0.12e18,
            paymentInterval:  ROUND_MONTH * 2,
            numberOfPayments: 3
        });

        requestRedeem(lp1, 1_000_000e6);
        requestRedeem(lp2, 4_000_000e6);
        requestRedeem(lp3, 5_000_000e6);

        vm.warp(start + ROUND_MONTH);

        assertEq(pool.totalAssets(), 10_050_000e6 - 1);  // Exchange rate is 1.005 with rounding error

        assertEq(withdrawalManager.lockedShares(lp1), 1_000_000e6);
        assertEq(withdrawalManager.lockedShares(lp2), 4_000_000e6);
        assertEq(withdrawalManager.lockedShares(lp3), 5_000_000e6);

        assertEq(withdrawalManager.exitCycleId(lp1), 3);
        assertEq(withdrawalManager.exitCycleId(lp2), 3);
        assertEq(withdrawalManager.exitCycleId(lp3), 3);

        assertEq(withdrawalManager.totalCycleShares(3), 10_000_000e6);
        assertEq(withdrawalManager.totalCycleShares(4), 0);

        uint256 withdrawnAssets1 = redeem(lp1, 1_000_000e6);

        assertEq(withdrawnAssets1, 499_999_999999);

        // AVR = 5m / (10m * 1.005) => 1m * (1 - AVR) = 502_487_562190
        uint256 remainingShares1 = 1_000_000e6 - uint256(1_000_000e6) * 5_000_000e6 / (10_050_000e6 - 1);

        assertEq(remainingShares1, 502_487_562190);

        assertEq(withdrawalManager.lockedShares(lp1),   remainingShares1);
        assertEq(withdrawalManager.totalCycleShares(3), 9_000_000_000000);
        assertEq(withdrawalManager.totalCycleShares(4), remainingShares1);

        assertEq(pool.totalSupply(), 9_000_000e6 + remainingShares1);
        assertEq(pool.totalAssets(), 10_050_000e6 - (withdrawnAssets1 + 1));
        assertEq(pool.totalAssets(), 9_550_000e6);

        vm.warp(start + ROUND_MONTH * 101 / 100);  // Warp another 1% through the interval

        assertEq(pool.totalAssets(), 10_050_000e6 - 1 - withdrawnAssets1 + 500e6); // previous TA  - 1 - 499_999_999999 + interest accrued in 1% of interval
        assertEq(pool.totalAssets(), 9_550_500e6);

        uint256 withdrawnAssets2 = redeem(lp2, 4_000_000e6);
        assertEq(withdrawnAssets2, 1_999_999_999999);

        // Exchange rate: totalAssets / totalShares = (~ 1.00505)
        // Total requested shares: 9m * exchange rate = 9_045_473_560208
        // AVR = 4.5m / (9m * 1.00505) => 4m * (1 - AVR) = 2_010_054_434388
        uint256 remainingShares2 = 4_000_000e6 - uint256(4_000_000e6) * (5_000_000e6 - withdrawnAssets1) / (9_045_473_560208);

        assertEq(remainingShares2, 2_010_054_434388);  // Higher than 2.009m from same exchange rate test

        assertEq(withdrawalManager.lockedShares(lp2),   remainingShares2);
        assertEq(withdrawalManager.totalCycleShares(3), 5_000_000_000000);
        assertEq(withdrawalManager.totalCycleShares(4), remainingShares1 + remainingShares2);  // LP1 + LP2 remaining shares

        assertEq(pool.totalSupply(), 5_000_000e6 + remainingShares1 + remainingShares2);
        assertEq(pool.totalAssets(), 10_050_000e6 - 1 - withdrawnAssets1 - withdrawnAssets2 + 500e6);
        assertEq(pool.totalAssets(), 7_550_500e6 + 1);

        vm.warp(start + ROUND_MONTH * 102 / 100);  // Warp another 1% through the interval

        assertEq(pool.totalAssets(), 7_550_500e6 + 1 + 500e6); // 500e6 more accrued from interval

        uint256 withdrawnAssets3 = redeem(lp3, 5_000_000e6);
        assertEq(withdrawnAssets3, 2_500_000e6 + 1);

        // Exchange rate: TotalAssets / TotalShares = 7551000000001 / 7512541996578 = (~ 1.0051)
        // Total requested shares: 5m * exchange rate = 5_025_595_865847
        // AVR = 2.5m / (5m * 1.0051) => 4m * (1 - AVR) = 2_512_732_751761
        uint256 remainingShares3 = 5_000_000e6 - uint256(5_000_000e6) * (5_000_000e6 - withdrawnAssets1 - withdrawnAssets2) / 5_025_595_865847;

        assertEq(remainingShares3, 2_512_732_751761);  // Higher than 2_512_437_810944 from same exchange rate test

        assertEq(withdrawalManager.lockedShares(lp3),   remainingShares3);
        assertEq(withdrawalManager.totalCycleShares(3), 0);
        assertEq(withdrawalManager.totalCycleShares(4), remainingShares1 + remainingShares2 + remainingShares3);

        assertEq(pool.totalAssets(), 10_050_000e6 - 1 - withdrawnAssets1 - withdrawnAssets2 - withdrawnAssets3 + 1_000e6);

        assertEq(pool.balanceOf(wm), remainingShares1 + remainingShares2 + remainingShares3);
        assertEq(pool.balanceOf(wm), 5_025_274_748339);  // Higher than 5_024_875_621890 from same exchange rate test

        assertEq(fundsAsset.balanceOf(lp1), 500_000e6   - 1);  // Rounding error
        assertEq(fundsAsset.balanceOf(lp2), 2_000_000e6 - 1);  // Rounding error
        assertEq(fundsAsset.balanceOf(lp3), 2_500_000e6 + 1);  // Rounding error
    }

}
