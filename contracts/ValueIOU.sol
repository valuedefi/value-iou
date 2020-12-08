// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.6.12;

import "./ValueIOUTokenInterface.sol";
import "./ValueIOUTokenStorage.sol";
import "./lib/SafeERC20.sol";

contract ValueIOUToken is ValueIOUTokenInterface, ValueIOUTokenStorage {
    // Modifiers
    modifier onlyGov() {
        require(msg.sender == gov);
        _;
    }

    modifier onlyRebaser() {
        require(msg.sender == rebaser);
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == rebaser || msg.sender == gov, "not minter");
        _;
    }

    modifier validRecipient(address to) {
        require(to != address(0x0));
        require(to != address(this));
        _;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) public virtual {
        require(valueIOUsScalingFactor_ == 0, "already initialized");
        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    function valueIOUsScalingFactor() external view override returns (uint256) {
        return valueIOUsScalingFactor_;
    }

    /**
     * @notice Computes the current max scaling factor
     */
    function maxScalingFactor() external view override returns (uint256) {
        return _maxScalingFactor();
    }

    function _maxScalingFactor() internal view returns (uint256) {
        // scaling factor can only go up to 2**256-1 = initSupply * valueIOUsScalingFactor_
        // this is used to check if valueIOUsScalingFactor_ will be too high to compute balances when rebasing.
        return uint256(-1) / initSupply;
    }

    /**
     * @notice Mints new tokens, increasing totalSupply, initSupply, and a users balance.
     * @dev Limited to onlyMinter modifier
     */
    function mint(address to, uint256 amount) external override onlyMinter returns (bool) {
        _mint(to, amount);
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        // increase totalSupply
        totalSupply = totalSupply.add(amount);

        // get underlying value
        uint256 valueIOUValue = _fragmentToValueIOU(amount);

        // increase initSupply
        initSupply = initSupply.add(valueIOUValue);

        // make sure the mint didnt push maxScalingFactor too low
        require(valueIOUsScalingFactor_ <= _maxScalingFactor(), "max scaling factor too low");

        // add balance
        _valueIOUBalances[to] = _valueIOUBalances[to].add(valueIOUValue);

        // add delegates to the minter
        emit Mint(to, amount);
    }

    /* - ERC20 functionality - */

    /**
     * @dev Transfer tokens to a specified address.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     * @return True on success, false otherwise.
     */
    function transfer(address to, uint256 value) external override validRecipient(to) returns (bool) {
        // underlying balance is stored in valueIOUs, so divide by current scaling factor

        // note, this means as scaling factor grows, dust will be untransferrable.
        // minimum transfer value == valueIOUsScalingFactor_ / 1e24;

        // get amount in underlying
        uint256 valueIOUValue = _fragmentToValueIOU(value);

        // sub from balance of sender
        _valueIOUBalances[msg.sender] = _valueIOUBalances[msg.sender].sub(valueIOUValue);

        // add to balance of receiver
        _valueIOUBalances[to] = _valueIOUBalances[to].add(valueIOUValue);
        emit Transfer(msg.sender, to, value);

        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * @param from The address you want to send tokens from.
     * @param to The address you want to transfer to.
     * @param value The amount of tokens to be transferred.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override validRecipient(to) returns (bool) {
        // decrease allowance
        _allowedFragments[from][msg.sender] = _allowedFragments[from][msg.sender].sub(value);

        // get value in valueIOUs
        uint256 valueIOUValue = _fragmentToValueIOU(value);

        // sub from from
        _valueIOUBalances[from] = _valueIOUBalances[from].sub(valueIOUValue);
        _valueIOUBalances[to] = _valueIOUBalances[to].add(valueIOUValue);
        emit Transfer(from, to, value);
        return true;
    }

    /**
     * @param who The address to query.
     * @return The balance of the specified address.
     */
    function balanceOf(address who) external view override returns (uint256) {
        return _valueIOUToFragment(_valueIOUBalances[who]);
    }

    /** @notice Currently returns the internal storage amount
     * @param who The address to query.
     * @return The underlying balance of the specified address.
     */
    function balanceOfUnderlying(address who) external view override returns (uint256) {
        return _valueIOUBalances[who];
    }

    /**
     * @dev Function to check the amount of tokens that an owner has allowed to a spender.
     * @param owner_ The address which owns the funds.
     * @param spender The address which will spend the funds.
     * @return The number of tokens still available for the spender.
     */
    function allowance(address owner_, address spender) external view override returns (uint256) {
        return _allowedFragments[owner_][spender];
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of
     * msg.sender. This method is included for ERC20 compatibility.
     * increaseAllowance and decreaseAllowance should be used instead.
     * Changing an allowance with this method brings the risk that someone may transfer both
     * the old and the new allowance - if they are both greater than zero - if a transfer
     * transaction is mined before the later approve() call is mined.
     *
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) external override returns (bool) {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner has allowed to a spender.
     * This method should be used instead of approve() to avoid the double approval vulnerability
     * described above.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue) external override returns (bool) {
        _allowedFragments[msg.sender][spender] = _allowedFragments[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner has allowed to a spender.
     *
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) external override returns (bool) {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue.sub(subtractedValue);
        }
        emit Approval(msg.sender, spender, _allowedFragments[msg.sender][spender]);
        return true;
    }

    /* - Governance Functions - */

    /** @notice sets the rebaser
     * @param rebaser_ The address of the rebaser contract to use for authentication.
     */
    function _setRebaser(address rebaser_) external override onlyGov {
        address oldRebaser = rebaser;
        rebaser = rebaser_;
        emit NewRebaser(oldRebaser, rebaser_);
    }

    function setGovernance(address _governance) external override onlyGov {
        address oldGov = gov;
        gov = _governance;
        emit NewGov(oldGov, _governance);
    }

    /* - Extras - */

    /**
     * @notice Initiates a new rebase operation, provided the minimum time period has elapsed.
     *
     * @dev The supply adjustment equals (totalSupply * DeviationFromTargetRate) / rebaseLag
     *      Where DeviationFromTargetRate is (MarketOracleRate - targetRate) / targetRate
     *      and targetRate is CpiOracleRate / baseCpi
     */
    function rebase(
        uint256 epoch,
        uint256 indexDelta,
        bool positive
    ) external override onlyRebaser returns (uint256) {
        // no change
        if (indexDelta == 0) {
            emit Rebase(epoch, valueIOUsScalingFactor_, valueIOUsScalingFactor_);
            return totalSupply;
        }

        // for events
        uint256 prevValueIOUsScalingFactor = valueIOUsScalingFactor_;

        if (!positive) {
            // negative rebase, decrease scaling factor
            valueIOUsScalingFactor_ = valueIOUsScalingFactor_.mul(BASE.sub(indexDelta)).div(BASE);
        } else {
            // positive reabse, increase scaling factor
            uint256 newScalingFactor = valueIOUsScalingFactor_.mul(BASE.add(indexDelta)).div(BASE);
            if (newScalingFactor < _maxScalingFactor()) {
                valueIOUsScalingFactor_ = newScalingFactor;
            } else {
                valueIOUsScalingFactor_ = _maxScalingFactor();
            }
        }

        // update total supply, correctly
        totalSupply = _valueIOUToFragment(initSupply);

        emit Rebase(epoch, prevValueIOUsScalingFactor, valueIOUsScalingFactor_);
        return totalSupply;
    }

    function valueIOUToFragment(uint256 valueIOU) external view override returns (uint256) {
        return _valueIOUToFragment(valueIOU);
    }

    function fragmentToValueIOU(uint256 value) external view override returns (uint256) {
        return _fragmentToValueIOU(value);
    }

    function _valueIOUToFragment(uint256 valueIOU) internal view returns (uint256) {
        return valueIOU.mul(valueIOUsScalingFactor_).div(internalDecimals);
    }

    function _fragmentToValueIOU(uint256 value) internal view returns (uint256) {
        return value.mul(internalDecimals).div(valueIOUsScalingFactor_);
    }

    // Rescue tokens
    function rescueTokens(
        address token,
        address to,
        uint256 amount
    ) external onlyGov returns (bool) {
        // transfer to
        SafeERC20.safeTransfer(IERC20(token), to, amount);
        return true;
    }
}

contract ValueIOU is ValueIOUToken {
    /**
     * @notice Initialize the new money market
     * @param name_ ERC-20 name of this token
     * @param symbol_ ERC-20 symbol of this token
     * @param decimals_ ERC-20 decimal precision of this token
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) public override {
        super.initialize(name_, symbol_, decimals_);
        valueIOUsScalingFactor_ = BASE;
        initSupply = 0;
        totalSupply = 0;

        gov = msg.sender;
    }
}
