// Freezer
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./VintageWine.sol";

contract Cellar is
    ERC20("Staked VintageWine", "SVINTAGEWINE"),
    Ownable,
    Pausable
{
    using SafeERC20 for VintageWine;
    using SafeMath for uint256;

    uint256 public constant DELAYED_UNSTAKE_LOCKUP_PERIOD = 2 days;
    uint256 public constant DELAYED_UNSTAKE_BURN_PERCENT = 10;
    uint256 public constant QUICK_UNSTAKE_CONTRIBUTION_PERCENT = 50;
    uint256 public constant QUICK_UNSTAKE_BURN_PERCENT = 25;

    VintageWine public vintageWine;
    uint256 public frozenVintageWine; // VINTAGEWINE pending withdrawal

    mapping(address => uint256) public unlockAmounts;
    mapping(address => uint256) public unlockTimestamps;

    uint256 public stakeTime;

    constructor(VintageWine _vintageWine) {
        vintageWine = _vintageWine;
    }

    // Views

    function vintageWineBalance() public view returns (uint256 balance) {
        return vintageWine.balanceOf(address(this)) - frozenVintageWine;
    }

    function _unstakeOutput(uint256 _share)
        internal
        view
        returns (uint256 output)
    {
        uint256 totalShares = totalSupply();
        return _share.mul(vintageWineBalance()).div(totalShares);
    }

    // External

    function stake(uint256 _amount) external whenNotPaused {
        require(stakeStarted(), "You can't stake yet");
        uint256 totalShares = totalSupply();
        // If no sVINTAGEWINE exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || vintageWineBalance() == 0) {
            _mint(_msgSender(), _amount);
        } else {
            uint256 share = _amount.mul(totalShares).div(vintageWineBalance());
            _mint(_msgSender(), share);
        }

        vintageWine.transferToCellar(_msgSender(), _amount);
    }

    function quickUnstake(uint256 _share) external whenNotPaused {
        // QUICK_UNSTAKE_CONTRIBUTION_PERCENT of the claimable VINTAGEWINE will remain in the cellar
        // the rest is transfered to the staker
        uint256 unstakeOutput = _unstakeOutput(_share);
        uint256 output = unstakeOutput
            .mul(100 - QUICK_UNSTAKE_CONTRIBUTION_PERCENT)
            .div(100);
        // QUICK_UNSTAKE_BURN_PERCENT of the claimable VINTAGEWINE is burned
        uint256 amountSpoiled = unstakeOutput
            .mul(QUICK_UNSTAKE_BURN_PERCENT)
            .div(100);

        // burn staker's share
        _burn(_msgSender(), _share);

        vintageWine.burn(address(this), amountSpoiled);
        vintageWine.safeTransfer(_msgSender(), output);
    }

    /**
     * @dev _share argument specified in sVINTAGEWINE
     */
    function prepareDelayedUnstake(uint256 _share) external whenNotPaused {
        // calculate output and burn staker's share
        uint256 output = _unstakeOutput(_share); //converts svintageWine values to vintageWine
        _burn(_msgSender(), _share);

        // calculate and burn amount of output spoiled
        uint256 amountSpoiled = output.mul(DELAYED_UNSTAKE_BURN_PERCENT).div(
            100
        );

        // remove amountSpoiled from output
        output -= amountSpoiled;

        unlockAmounts[_msgSender()] += output;
        unlockTimestamps[_msgSender()] =
            block.timestamp +
            DELAYED_UNSTAKE_LOCKUP_PERIOD;
        frozenVintageWine += output;

        vintageWine.burn(address(this), amountSpoiled);
    }

    /**
     * @dev argument specified in VINTAGEWINE, not sVINTAGEWINE
     */
    function claimDelayedUnstake(uint256 _amount) external whenNotPaused {
        require(
            block.timestamp >= unlockTimestamps[_msgSender()],
            "VINTAGEWINE not yet unlocked"
        );
        require(
            _amount <= unlockAmounts[_msgSender()],
            "insufficient locked balance"
        );

        // deduct from unlocked
        unlockAmounts[_msgSender()] -= _amount;

        frozenVintageWine -= _amount;

        // transfer claim
        vintageWine.safeTransfer(_msgSender(), _amount);
    }

    // Admin

    function stakeStarted() public view returns (bool) {
        return stakeTime != 0 && block.timestamp >= stakeTime;
    }

    function setStakeStartTime(uint256 _startTime) external onlyOwner {
        require(
            _startTime >= block.timestamp,
            "startTime cannot be in the past"
        );
        require(!stakeStarted(), "staking already started");
        stakeTime = _startTime;
    }
}
