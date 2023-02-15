// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoan, IFixedTermLoanManagerStructs, ILoanLike } from "../contracts/interfaces/Interfaces.sol";

import { BalanceAssertions } from "./BalanceAssertions.sol";
import { TestBase }          from "./TestBase.sol";

contract TestBaseWithAssertions is TestBase, BalanceAssertions {

    /**************************************************************************************************************************************/
    /*** State Assertion Functions                                                                                                      ***/
    /**************************************************************************************************************************************/

    function assertLoanState(
        address loan,
        uint256 principal,
        uint256 refinanceInterest,
        uint256 paymentDueDate,
        uint256 paymentsRemaining
    ) internal {
        assertEq(IFixedTermLoan(loan).principal(),          principal,         "principal");
        assertEq(IFixedTermLoan(loan).refinanceInterest(),  refinanceInterest, "refinanceInterest");
        assertEq(IFixedTermLoan(loan).nextPaymentDueDate(), paymentDueDate,    "nextPaymentDueDate");
        assertEq(IFixedTermLoan(loan).paymentsRemaining(),  paymentsRemaining, "paymentsRemaining");
    }

    function assertLoanState(
        address loan,
        uint256 principal,
        uint256 incomingPrincipal,
        uint256 incomingInterest,
        uint256 incomingFees,
        uint256 refinanceInterest,
        uint256 paymentDueDate,
        uint256 paymentsRemaining
    ) internal {
        ( uint256 principalPayment, uint256 interest, uint256 fees ) = IFixedTermLoan(loan).getNextPaymentBreakdown();

        assertEq(interest,         incomingInterest,  "interest");
        assertEq(fees,             incomingFees,      "fees");
        assertEq(principalPayment, incomingPrincipal, "incoming principal");

        assertEq(IFixedTermLoan(loan).principal(),          principal,         "principal");
        assertEq(IFixedTermLoan(loan).refinanceInterest(),  refinanceInterest, "refinanceInterest");
        assertEq(IFixedTermLoan(loan).nextPaymentDueDate(), paymentDueDate,    "nextPaymentDueDate");
        assertEq(IFixedTermLoan(loan).paymentsRemaining(),  paymentsRemaining, "paymentsRemaining");
    }

    function assertLoanInfoWasDeleted(address loan) internal {
        uint256 loanId = loanManager.paymentIdOf(loan);
        assertEq(loanId, 0);
    }

    // TODO: Investigate reverting back to tuples to expose changes easier.
    function assertPaymentInfo(
        address loan,
        uint256 incomingNetInterest,
        uint256 refinanceInterest,
        uint256 issuanceRate,
        uint256 startDate,
        uint256 paymentDueDate,
        uint256 platformFeeRate,
        uint256 delegateFeeRate
    )
        internal
    {
        IFixedTermLoanManagerStructs.PaymentInfo memory loanInfo =
            IFixedTermLoanManagerStructs(ILoanLike(loan).lender()).payments(loanManager.paymentIdOf(loan));

        assertEq(loanInfo.incomingNetInterest,       incomingNetInterest, "loanInfo.incomingNetInterest");
        assertEq(loanInfo.refinanceInterest,         refinanceInterest,   "loanInfo.refinanceInterest");
        assertEq(loanInfo.issuanceRate,              issuanceRate,        "loanInfo.issuanceRate");
        assertEq(loanInfo.startDate,                 startDate,           "loanInfo.startDate");
        assertEq(loanInfo.paymentDueDate,            paymentDueDate,      "loanInfo.paymentDueDate");
        assertEq(loanInfo.platformManagementFeeRate, platformFeeRate,     "loanInfo.platformManagementFeeRate");
        assertEq(loanInfo.delegateManagementFeeRate, delegateFeeRate,     "loanInfo.delegateFeeRate");
    }

    function assertLoanManager(
        uint256 accruedInterest,
        uint256 accountedInterest,
        uint256 principalOut,
        uint256 assetsUnderManagement,
        uint256 issuanceRate,
        uint256 domainStart,
        uint256 domainEnd,
        uint256 unrealizedLosses
    ) internal {
        assertEq(loanManager.getAccruedInterest(),    accruedInterest,       "getAccruedInterest");
        assertEq(loanManager.accountedInterest(),     accountedInterest,     "accountedInterest");
        assertEq(loanManager.principalOut(),          principalOut,          "principalOut");
        assertEq(loanManager.assetsUnderManagement(), assetsUnderManagement, "assetsUnderManagement");
        assertEq(loanManager.issuanceRate(),          issuanceRate,          "issuanceRate");
        assertEq(loanManager.domainStart(),           domainStart,           "domainStart");
        assertEq(loanManager.domainEnd(),             domainEnd,             "domainEnd");
        assertEq(loanManager.unrealizedLosses(),      unrealizedLosses,      "unrealizedLosses");
    }

    function assertLiquidationInfo(
        address loan,
        uint256 principal,
        uint256 interest,
        uint256 lateInterest,
        uint256 platformFees,
        bool    liquidatorExists,
        bool    triggeredByGovernor
    ) internal {
        IFixedTermLoanManagerStructs.LiquidationInfo memory liquidationInfo =
            IFixedTermLoanManagerStructs(ILoanLike(loan).lender()).liquidationInfo(loan);

        assertEq(liquidationInfo.principal,    principal,    "liquidationInfo.principal");
        assertEq(liquidationInfo.interest,     interest,     "liquidationInfo.interest");
        assertEq(liquidationInfo.lateInterest, lateInterest, "liquidationInfo.lateInterest");
        assertEq(liquidationInfo.platformFees, platformFees, "liquidationInfo.platformFees");

        assertTrue(liquidatorExists ? liquidationInfo.liquidator != address(0) : liquidationInfo.liquidator == address(0), "liquidator exists");
        assertTrue(liquidationInfo.triggeredByGovernor == triggeredByGovernor, "triggeredByGovernor");
    }

    function assertPoolState(uint256 totalAssets, uint256 totalSupply, uint256 unrealizedLosses, uint256 availableLiquidity) internal {
        assertEq(pool.totalAssets(),                  totalAssets,        "totalAssets");
        assertEq(pool.totalSupply(),                  totalSupply,        "totalSupply");
        assertEq(pool.unrealizedLosses(),             unrealizedLosses,   "unrealizedLosses");
        assertEq(fundsAsset.balanceOf(address(pool)), availableLiquidity, "availableLiquidity");
    }

    function assertPoolManager(uint256 totalAssets, uint256 unrealizedLosses) internal {
        assertEq(poolManager.totalAssets(),      totalAssets,      "totalAssets");
        assertEq(poolManager.unrealizedLosses(), unrealizedLosses, "unrealizedLosses");
    }

    function assertTotalAssets(uint256 totalAssets) internal {
        assertEq(poolManager.totalAssets(), totalAssets);
    }

    function assertWithdrawalManagerState(
        address lp,
        uint256 lockedShares,
        uint256 previousExitCycleId,
        uint256 previousCycleTotalShares,
        uint256 currentExitCycleId,
        uint256 currentCycleTotalShares,
        uint256 withdrawalManagerTotalShares
    ) internal {
        assertEq(withdrawalManager.lockedShares(lp), lockedShares);
        assertEq(withdrawalManager.exitCycleId(lp),  currentExitCycleId);

        assertEq(withdrawalManager.totalCycleShares(previousExitCycleId), previousCycleTotalShares);
        assertEq(withdrawalManager.totalCycleShares(currentExitCycleId),  currentCycleTotalShares);

        assertEq(pool.balanceOf(address(withdrawalManager)), withdrawalManagerTotalShares);
    }

}
