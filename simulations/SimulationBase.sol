// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IPool, IPoolManager } from "../contracts/interfaces/Interfaces.sol";

import { Address } from "../contracts/Contracts.sol";

import { DepositLiquidityAction } from "./actions/DepositLiquidityAction.sol";
import { LoanActionGenerator }    from "./actions/LoanActionGenerator.sol";

import { BusinessSimLogger } from "./loggers/BusinessSimLogger.sol";
import { LoanLogger }        from "./loggers/LoanLogger.sol";
import { LoanManagerLogger } from "./loggers/LoanManagerLogger.sol";
import { PoolLogger }        from "./loggers/PoolLogger.sol";
import { PoolManagerLogger } from "./loggers/PoolManagerLogger.sol";

import { LoanScenario }   from "./LoanScenario.sol";
import { PoolSimulation } from "./PoolSimulation.sol";

import { TestBase } from "../tests/TestBase.sol";

contract SimulationBase is TestBase {

    uint256 initialCover;
    uint256 initialLiquidity;

    PoolSimulation simulation;

    LoanScenario[] scenarios;

    function setUp() public virtual override {
        super.setUp();
    }

    function setUpSimulation() public {
        // Create the simulation.
        simulation = new PoolSimulation();

        // TODO: Add the required `initialCover` pool cover.

        // Add the initial pool funding action.
        simulation.add(new DepositLiquidityAction({
            timestamp_:   block.timestamp,
            description_: "Deposit assets into the pool",
            pool_:        address(pool),
            lp_:          address(new Address()),          // TODO: Replace Address with randomly generated EOA.
            amount_:      initialLiquidity
        }));

        // Generate all the actions based on the loan scenarios.
        LoanActionGenerator generator_ = new LoanActionGenerator();
        for (uint256 i_; i_ < scenarios.length; i_++) {
            simulation.add(generator_.generateActions(scenarios[i_]));
        }
    }

    function setUpAllLoggers(string memory filepath_) public {
        IPool        pool_        = IPool(address(pool));
        IPoolManager poolManager_ = IPoolManager(address(poolManager));

        // Add all loggers here in order to record contract states during the simulation.
        simulation.record(new PoolLogger(pool_,                       string(abi.encodePacked("output/", filepath_, "/pool.csv"))));
        simulation.record(new PoolManagerLogger(poolManager_,         string(abi.encodePacked("output/", filepath_, "/pool-manager.csv"))));
        simulation.record(new LoanManagerLogger(address(loanManager), string(abi.encodePacked("output/", filepath_, "/loan-manager.csv"))));

        for (uint256 i_; i_ < scenarios.length; i_++) {
            simulation.record(
                new LoanLogger(
                    address(scenarios[i_].loan()),
                    string(abi.encodePacked("output/", filepath_, "/", scenarios[i_].name(), ".csv"))
                )
            );
        }
    }

    function setUpBusinessLogger(string memory filepath_) public {
        // Add all loggers here in order to record contract states during the simulation.
        simulation.record(new BusinessSimLogger({
            loanManager_:  address(loanManager),
            poolDelegate_: address(poolDelegate),
            poolManager_:  address(poolManager),
            treasury_:     address(treasury),
            filepath_:     string(abi.encodePacked("output/", filepath_, "/business-sim.csv"))
        }));
    }

}
