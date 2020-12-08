// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./lib/SafeERC20.sol";
import "./lib/SafeMath.sol";
import "./lib/IUniswapV2Pair.sol";
import "./ValueIOUTokenInterface.sol";

interface BAL {
    function gulp(address token) external;
}

contract ValueIOURebaser {
    using SafeMath for uint256;

    modifier onlyGov() {
        require(msg.sender == gov);
        _;
    }

    struct Transaction {
        bool enabled;
        address destination;
        bytes data;
    }

    /// @notice an event emitted when a transaction fails
    event TransactionFailed(address indexed destination, uint256 index, bytes data);

    /**
     * @notice Event emitted when gov is changed
     */
    event NewGov(address oldGov, address newGov);

    // Stable ordering is not guaranteed.
    Transaction[] public transactions;

    /// @notice Governance address
    address public gov;

    /// @notice Block timestamp of last rebase operation
    uint256 public lastRebaseTimestampSec;

    /// @notice The rebase window begins this many seconds into the minRebaseTimeInterval period.
    // For example if minRebaseTimeInterval is 24hrs, it represents the time of day in seconds.
    uint256 public rebaseWindowOffsetSec;

    /// @notice The length of the time window where a rebase operation is allowed to execute, in seconds.
    uint256 public rebaseWindowLengthSec;

    /// @notice The number of rebase cycles since inception
    uint256 public epoch;

    // rebasing is not active initially. It can be activated at T+12 hours from
    // deployment time
    ///@notice boolean showing rebase activation status
    bool public rebasingActive;

    /// @notice ValueIOU token address
    address public valueIOUAddress;

    /// @notice list of uniswap pairs to sync
    address[] public uniSyncPairs;

    /// @notice list of balancer pairs to gulp
    address[] public balGulpPairs;

    /// @notice list of value liquid pairs to gulp
    address[] public liquidGulpPairs;

    /// @notice last TWAP cumulative price;
    uint256 public priceCumulativeLast;

    uint256 public constant BASE = 10**18;

    uint256 public constant DELTA_PER_WEEK = 1834568839232956; // BASE 10^18

    constructor(address valueIOUAddress_) public {
        rebaseWindowLengthSec = 1 weeks;
        // first Monday
        rebaseWindowOffsetSec = 345600;

        valueIOUAddress = valueIOUAddress_;

        // Changed in deployment scripts to facilitate protocol initiation
        gov = msg.sender;
    }

    function removeUniPair(uint256 index) public onlyGov {
        if (index >= uniSyncPairs.length) return;

        for (uint256 i = index; i < uniSyncPairs.length - 1; i++) {
            uniSyncPairs[i] = uniSyncPairs[i + 1];
        }
        uniSyncPairs.pop();
    }

    function removeBalPair(uint256 index) public onlyGov {
        if (index >= balGulpPairs.length) return;

        for (uint256 i = index; i < balGulpPairs.length - 1; i++) {
            balGulpPairs[i] = balGulpPairs[i + 1];
        }
        balGulpPairs.pop();
    }

    function removeValueLiquidPair(uint256 index) public onlyGov {
        if (index >= liquidGulpPairs.length) return;

        for (uint256 i = index; i < liquidGulpPairs.length - 1; i++) {
            liquidGulpPairs[i] = liquidGulpPairs[i + 1];
        }
        liquidGulpPairs.pop();
    }

    /**
    @notice Adds pairs to sync
    *
    */
    function addSyncPairs(
        address[] memory uniSyncPairs_,
        address[] memory balGulpPairs_,
        address[] memory liquidGulpPairs_
    ) public onlyGov {
        for (uint256 i = 0; i < uniSyncPairs_.length; i++) {
            uniSyncPairs.push(uniSyncPairs_[i]);
        }

        for (uint256 i = 0; i < balGulpPairs_.length; i++) {
            balGulpPairs.push(balGulpPairs_[i]);
        }

        for (uint256 i = 0; i < liquidGulpPairs_.length; i++) {
            liquidGulpPairs.push(liquidGulpPairs_[i]);
        }
    }

    /**
    @notice Uniswap synced pairs
    *
    */
    function getUniSyncPairs() public view returns (address[] memory) {
        address[] memory pairs = uniSyncPairs;
        return pairs;
    }

    /**
    @notice Balancer synced pairs
    *
    */
    function getBalGulpPairs() public view returns (address[] memory) {
        address[] memory pairs = balGulpPairs;
        return pairs;
    }

    /**
    @notice Balancer synced pairs
    *
    */
    function getLiquidGulpPairs() public view returns (address[] memory) {
        address[] memory pairs = liquidGulpPairs;
        return pairs;
    }

    /**
     * @param _governance The address of the rebaser contract to use for authentication.
     */
    function setGovernance(address _governance) external onlyGov {
        address oldGov = gov;
        gov = _governance;
        emit NewGov(oldGov, _governance);
    }

    /**
     * @notice Initiates a new rebase operation, provided the minimum time period has elapsed.
     *
     * @dev The supply adjustment equals (_totalSupply * DeviationFromTargetRate) / rebaseLag
     *      Where DeviationFromTargetRate is (MarketOracleRate - targetRate) / targetRate
     *      and targetRate is 1e18
     */
    function rebase() external onlyGov {
        require(rebasingActive, "rebase is disable");
        // ensure rebasing at correct time
        // This comparison also ensures there is no reentrancy.
        require(lastRebaseTimestampSec.add(rebaseWindowLengthSec) < now);

        // Snap the rebase time to the start of this window.
        lastRebaseTimestampSec = now.sub(now.sub(rebaseWindowOffsetSec).mod(rebaseWindowLengthSec));

        epoch = epoch.add(1);

        uint256 indexDelta = DELTA_PER_WEEK;

        // Apply the Dampening factor.

        ValueIOUTokenInterface valueIOU = ValueIOUTokenInterface(valueIOUAddress);

        require(valueIOU.valueIOUsScalingFactor().mul(BASE.add(indexDelta)).div(BASE) < valueIOU.maxScalingFactor(), "new scaling factor will be too big");

        // rebase
        // ignore returned var
        valueIOU.rebase(epoch, indexDelta, true);

        // perform actions after rebase
        afterRebase();
    }

    function afterRebase() internal {
        // update uniswap pairs
        for (uint256 i = 0; i < uniSyncPairs.length; i++) {
            UniswapPair(uniSyncPairs[i]).sync();
        }

        // update balancer pairs
        for (uint256 i = 0; i < balGulpPairs.length; i++) {
            BAL(balGulpPairs[i]).gulp(valueIOUAddress);
        }

        // update liquid pairs
        for (uint256 i = 0; i < liquidGulpPairs.length; i++) {
            BAL(liquidGulpPairs[i]).gulp(valueIOUAddress);
        }

        // call any extra functions
        for (uint256 i = 0; i < transactions.length; i++) {
            Transaction storage t = transactions[i];
            if (t.enabled) {
                bool result = externalCall(t.destination, t.data);
                if (!result) {
                    emit TransactionFailed(t.destination, i, t.data);
                    revert("Transaction Failed");
                }
            }
        }
    }

    /* -- Rebase helpers -- */

    /**
     * @notice Adds a transaction that gets called for a downstream receiver of rebases
     * @param destination Address of contract destination
     * @param data Transaction data payload
     */
    function addTransaction(address destination, bytes calldata data) external onlyGov {
        transactions.push(Transaction({enabled: true, destination: destination, data: data}));
    }

    /**
     * @param index Index of transaction to remove.
     *              Transaction ordering may have changed since adding.
     */
    function removeTransaction(uint256 index) external onlyGov {
        require(index < transactions.length, "index out of bounds");

        if (index < transactions.length - 1) {
            transactions[index] = transactions[transactions.length - 1];
        }

        transactions.pop();
    }

    /**
     * @param index Index of transaction. Transaction ordering may have changed since adding.
     * @param enabled True for enabled, false for disabled.
     */
    function setTransactionEnabled(uint256 index, bool enabled) external onlyGov {
        require(index < transactions.length, "index must be in range of stored tx list");
        transactions[index].enabled = enabled;
    }

    function setRebasingActive(bool _rebasingActive) external onlyGov {
        rebasingActive = _rebasingActive;
    }

    /**
     * @dev wrapper to call the encoded transactions on downstream consumers.
     * @param destination Address of destination contract.
     * @param data The encoded data payload.
     * @return True on success
     */
    function externalCall(address destination, bytes memory data) internal returns (bool) {
        bool result;
        assembly {
            // solhint-disable-line no-inline-assembly
            // "Allocate" memory for output
            // (0x40 is where "free memory" pointer is stored by convention)
            let outputAddress := mload(0x40)

            // First 32 bytes are the padded length of data, so exclude that
            let dataAddress := add(data, 32)

            result := call(
                // 34710 is the value that solidity is currently emitting
                // It includes callGas (700) + callVeryLow (3, to pay for SUB)
                // + callValueTransferGas (9000) + callNewAccountGas
                // (25000, in case the destination address does not exist and needs creating)
                5000, // gas remaining
                destination,
                0, // transfer value in wei
                dataAddress,
                mload(data), // Size of the input, in bytes. Stored in position 0 of the array.
                outputAddress,
                0 // Output is ignored, therefore the output size is zero
            )
        }
        return result;
    }

    // Rescue tokens
    function rescueTokens(
        address token,
        address to,
        uint256 amount
    ) external onlyGov returns (bool) {
        // transfer to
        SafeERC20.safeTransfer(IERC20(token), to, amount);
    }
}
