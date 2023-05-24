// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IGlobals,
    INonTransparentProxy,
    IProxiedLike,
    IProxyFactoryLike
} from "../../contracts/interfaces/Interfaces.sol";

import {
    FixedTermLoan,
    FixedTermLoanInitializer,
    FixedTermLoanManager,
    FixedTermLoanManagerInitializer,
    FixedTermLoanV5Migrator,
    FixedTermRefinancer,
    Globals,
    OpenTermLoan,
    OpenTermLoanFactory,
    OpenTermLoanInitializer,
    OpenTermLoanManager,
    OpenTermLoanManagerFactory,
    OpenTermLoanManagerInitializer,
    OpenTermRefinancer,
    PoolDeployer,
    PoolManager,
    PoolManagerInitializer
} from "../../contracts/Contracts.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { UpgradeAddressRegistry as AddressRegistry } from "./UpgradeAddressRegistry.sol";

contract ProtocolUpgradeBase is AddressRegistry, ProtocolActions {

    // TODO: Add assert(false) for old keys for isInstance after changes are made (ie. LOAN_MANAGER etc)
    // TODO: Check bytecode hashes for contracts, sync on which contracts are needed
    // TODO: Assert entire storage layout against all real upgrades
    // TODO: Update timestamp to current and add newest maven 11 pool and updated loan set

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17296000);
    }

    /**************************************************************************************************************************************/
    /*** Deployment Helper Functions                                                                                                    ***/
    /**************************************************************************************************************************************/

    // Step 1: Deploy all new contracts necessary for protocol upgrade.
    function _deployAllNewContracts() internal {
        // Upgrade contracts for Fixed Term Loan
        fixedTermLoanImplementationV500 = address(new FixedTermLoan());
        fixedTermLoanInitializerV500    = address(new FixedTermLoanInitializer());
        fixedTermLoanMigratorV500       = address(new FixedTermLoanV5Migrator());
        fixedTermRefinancerV2           = address(new FixedTermRefinancer());

        // Upgrade contracts for Fixed Term Loan Manager
        fixedTermLoanManagerImplementationV300 = address(new FixedTermLoanManager());
        fixedTermLoanManagerInitializerV300    = address(new FixedTermLoanManagerInitializer());

        // Upgrade contract for Globals
        globalsImplementationV2 = address(new Globals());

        // New contracts for Open Term Loan
        openTermLoanFactory            = address(new OpenTermLoanFactory(mapleGlobalsProxy));
        openTermLoanImplementationV100 = address(new OpenTermLoan());
        openTermLoanInitializerV100    = address(new OpenTermLoanInitializer());
        openTermRefinancerV1           = address(new OpenTermRefinancer());

        // New contracts for Open Term LoanManager
        openTermLoanManagerFactory            = address(new OpenTermLoanManagerFactory(mapleGlobalsProxy));
        openTermLoanManagerImplementationV100 = address(new OpenTermLoanManager());
        openTermLoanManagerInitializerV100    = address(new OpenTermLoanManagerInitializer());

        // New contract for PoolDeployer
        poolDeployerV2 = address(new PoolDeployer(mapleGlobalsProxy));

        // Upgrade contract for PoolManager
        poolManagerImplementationV200 = address(new PoolManager());
    }

    // Step 3. Enable instance keys at globals for factories, instances, and deployers.
    function _enableGlobalsKeys() internal {
        IGlobals globals_ = IGlobals(mapleGlobalsProxy);

        vm.startPrank(governor);

        // Apply new instance settings
        globals_.setValidInstanceOf("LIQUIDATOR_FACTORY",         liquidatorFactory,        true);
        globals_.setValidInstanceOf("POOL_MANAGER_FACTORY",       poolManagerFactory,       true);
        globals_.setValidInstanceOf("WITHDRAWAL_MANAGER_FACTORY", withdrawalManagerFactory, true);

        globals_.setValidInstanceOf("FT_LOAN_FACTORY", fixedTermLoanFactory, true);
        globals_.setValidInstanceOf("LOAN_FACTORY",    fixedTermLoanFactory, true);

        globals_.setValidInstanceOf("OT_LOAN_FACTORY", openTermLoanFactory, true);
        globals_.setValidInstanceOf("LOAN_FACTORY",    openTermLoanFactory, true);

        globals_.setValidInstanceOf("FT_LOAN_MANAGER_FACTORY", fixedTermLoanManagerFactory, true);
        globals_.setValidInstanceOf("LOAN_MANAGER_FACTORY",    fixedTermLoanManagerFactory, true);

        globals_.setValidInstanceOf("OT_LOAN_MANAGER_FACTORY", openTermLoanManagerFactory, true);
        globals_.setValidInstanceOf("LOAN_MANAGER_FACTORY",    openTermLoanManagerFactory, true);

        globals_.setValidInstanceOf("FT_REFINANCER", fixedTermRefinancerV2, true);
        globals_.setValidInstanceOf("REFINANCER",    fixedTermRefinancerV2, true);

        globals_.setValidInstanceOf("OT_REFINANCER", openTermRefinancerV1, true);
        globals_.setValidInstanceOf("REFINANCER",    openTermRefinancerV1, true);

        globals_.setValidInstanceOf("FEE_MANAGER", fixedTermFeeManagerV1, true);

        globals_.setCanDeployFrom(poolManagerFactory,       poolDeployerV2, true);
        globals_.setCanDeployFrom(withdrawalManagerFactory, poolDeployerV2, true);

        vm.stopPrank();
    }

    // Step 4: Allowlist all new contracts and register new versions and upgrades in factories.
    function _setupFactories() internal {
        vm.startPrank(governor);

        // PoolManager upgrade 100 => 200
        address poolManagerInitializer = IProxyFactoryLike(poolManagerFactory).migratorForPath(100, 100);
        IProxyFactoryLike(poolManagerFactory).registerImplementation(200, poolManagerImplementationV200, poolManagerInitializer);
        IProxyFactoryLike(poolManagerFactory).setDefaultVersion(200);
        IProxyFactoryLike(poolManagerFactory).enableUpgradePath(100, 200, address(0));

        // FixedTermLoan upgrade 400 => 500
        IProxyFactoryLike(fixedTermLoanFactory).registerImplementation(500, fixedTermLoanImplementationV500, fixedTermLoanInitializerV500);
        IProxyFactoryLike(fixedTermLoanFactory).setDefaultVersion(500);
        IProxyFactoryLike(fixedTermLoanFactory).enableUpgradePath(400, 500, fixedTermLoanMigratorV500);

        // FixedTermLoanManager upgrade 200 => 300
        IProxyFactoryLike(fixedTermLoanManagerFactory).registerImplementation(
            300,
            fixedTermLoanManagerImplementationV300,
            fixedTermLoanManagerInitializerV300
        );
        IProxyFactoryLike(fixedTermLoanManagerFactory).setDefaultVersion(300);
        IProxyFactoryLike(fixedTermLoanManagerFactory).enableUpgradePath(200, 300, address(0));

        // OpenTermLoan initial config for 100
        IProxyFactoryLike(openTermLoanFactory).registerImplementation(100, openTermLoanImplementationV100, openTermLoanInitializerV100);
        IProxyFactoryLike(openTermLoanFactory).setDefaultVersion(100);

        // OpenTermLoanManager initial config for 100
        IProxyFactoryLike(openTermLoanManagerFactory).registerImplementation(
            100,
            openTermLoanManagerImplementationV100,
            openTermLoanManagerInitializerV100
        );
        IProxyFactoryLike(openTermLoanManagerFactory).setDefaultVersion(100);

        vm.stopPrank();
    }

    // Step 5: Upgrade PoolManager and FixedTermLoanManager contracts as the Governor.
    function _upgradePoolContractsAsGovernor() internal {
        // Governor atomically upgrades all Pool Managers
        upgradePoolManagerAsGovernor(mavenPermissionedPoolManager, 200, new bytes(0));
        upgradePoolManagerAsGovernor(mavenUsdcPoolManager,         200, new bytes(0));
        upgradePoolManagerAsGovernor(mavenWethPoolManager,         200, new bytes(0));
        upgradePoolManagerAsGovernor(orthogonalPoolManager,        200, new bytes(0));
        upgradePoolManagerAsGovernor(icebreakerPoolManager,        200, new bytes(0));
        upgradePoolManagerAsGovernor(aqruPoolManager,              200, new bytes(0));
        upgradePoolManagerAsGovernor(mavenUsdc3PoolManager,        200, new bytes(0));

        // Governor atomically upgrades all Fixed Term Loan Managers
        upgradeLoanManagerAsGovernor(mavenPermissionedFixedTermLoanManager, 300, new bytes(0));
        upgradeLoanManagerAsGovernor(mavenUsdcFixedTermLoanManager,         300, new bytes(0));
        upgradeLoanManagerAsGovernor(mavenWethFixedTermLoanManager,         300, new bytes(0));
        upgradeLoanManagerAsGovernor(orthogonalFixedTermLoanManager,        300, new bytes(0));
        upgradeLoanManagerAsGovernor(icebreakerFixedTermLoanManager,        300, new bytes(0));
        upgradeLoanManagerAsGovernor(aqruFixedTermLoanManager,              300, new bytes(0));
        upgradeLoanManagerAsGovernor(mavenUsdc3FixedTermLoanManager,        300, new bytes(0));
    }

    // Step 6: Upgrade PoolManager and FixedTermLoanManager contracts as the Governor.
    function _upgradeLoanContractsAsSecurityAdmin() internal {
        // TODO: Determine if protocol is vulnerable at this stage

        // Security Admin atomically upgrades all Fixed Term Loans
        upgradeLoansAsSecurityAdmin(mavenPermissionedLoans, 500, new bytes(0));
        upgradeLoansAsSecurityAdmin(mavenUsdcLoans,         500, new bytes(0));
        upgradeLoansAsSecurityAdmin(mavenWethLoans,         500, new bytes(0));
        upgradeLoansAsSecurityAdmin(orthogonalLoans,        500, new bytes(0));
        upgradeLoansAsSecurityAdmin(icebreakerLoans,        500, new bytes(0));
        upgradeLoansAsSecurityAdmin(aqruLoans,              500, new bytes(0));
        upgradeLoansAsSecurityAdmin(mavenUsdc3Loans,        500, new bytes(0));
    }

    // Step 7. Disable instance keys at globals for factories, instances, and deployers.
    function _disableGlobalsKeys() internal {
        IGlobals globals_ = IGlobals(mapleGlobalsProxy);

        vm.startPrank(governor);

        // Remove old instance settings
        globals_.setValidInstanceOf("LIQUIDATOR",         liquidatorFactory,           false);
        globals_.setValidInstanceOf("LOAN_MANAGER",       fixedTermLoanManagerFactory, false);
        globals_.setValidInstanceOf("POOL_MANAGER",       poolManagerFactory,          false);
        globals_.setValidInstanceOf("WITHDRAWAL_MANAGER", withdrawalManagerFactory,    false);
        globals_.setValidInstanceOf("LOAN",               fixedTermLoanFactory,        false);

        globals_.setValidPoolDeployer(poolDeployerV1, false);

        vm.stopPrank();
    }

    // Full protocol upgrade
    function _performProtocolUpgrade() internal {
        // 1. Deploy all the new implementations and factories
        _deployAllNewContracts();

        // 2. Upgrade Globals, as the new version is needed to setup all the factories accordingly
        upgradeGlobals(mapleGlobalsProxy, globalsImplementationV2);

        // 3. Enable instance keys at globals for factories, instances, and deployers.
        _enableGlobalsKeys();

        // 4. Register the factories on globals and set the default versions.
        _setupFactories();

        // 5. Upgrade all the existing Pool and Loan Managers
        _upgradePoolContractsAsGovernor();

        // 6. Upgrade all the existing Loans
        _upgradeLoanContractsAsSecurityAdmin();

        // 7. Disable instance keys at globals for factories, instances, and deployers.
        _disableGlobalsKeys();
    }

    /**************************************************************************************************************************************/
    /*** Post-Deployment Helper Functions                                                                                               ***/
    /**************************************************************************************************************************************/

    function _addLoanManagers() internal {
        // Pool Delegate performs these actions
        // TODO: Determine if this needs to be part of upgrade or can be done after.
        addLoanManager(mavenPermissionedPoolManager, openTermLoanManagerFactory);
        addLoanManager(mavenUsdcPoolManager,         openTermLoanManagerFactory);
        addLoanManager(mavenWethPoolManager,         openTermLoanManagerFactory);
        addLoanManager(orthogonalPoolManager,        openTermLoanManagerFactory);
        addLoanManager(icebreakerPoolManager,        openTermLoanManagerFactory);
        addLoanManager(aqruPoolManager,              openTermLoanManagerFactory);
        addLoanManager(mavenUsdc3PoolManager,        openTermLoanManagerFactory);
    }

    function _addWithdrawalManagersToAllowlists() internal {
        // TODO: Whitelist the withdrawal managers for AQRU and Maven 03 on mainnet.
        allowLender(mavenUsdc3PoolManager, mavenUsdc3WithdrawalManager);
        allowLender(aqruPoolManager,       aqruWithdrawalManager);
    }

    function _deployActivateAndOpenNewPool(
        address       poolDelegate,
        address       fundsAsset,
        bool          publicPool,
        string memory name,
        string memory symbol,
        uint256       poolCoverAmount
    )
        internal returns (address poolManager_)
    {
        address[] memory loanManagerFactories = new address[](2);

        loanManagerFactories[0] = fixedTermLoanManagerFactory;
        loanManagerFactories[1] = openTermLoanManagerFactory;

        uint256[6] memory configParams_ = [type(uint256).max, 0.2e6, poolCoverAmount, 1 weeks, 2 days, 0];

        poolManager_ = deployAndActivatePool(
            poolDeployerV2,
            fundsAsset,
            mapleGlobalsProxy,
            poolDelegate,
            poolManagerFactory,
            withdrawalManagerFactory,
            name,
            symbol,
            loanManagerFactories,
            configParams_
        );

        if (publicPool == true) {
            openPool(poolManager_);
        }
    }

    // TODO: Add deprecation steps.

    /**************************************************************************************************************************************/
    /*** Assertion Helper Functions                                                                                                     ***/
    /**************************************************************************************************************************************/

    function _assertLoans(address[] memory loans, address implementation) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertEq(IProxiedLike(loans[i]).implementation(), implementation);
        }
    }

}
