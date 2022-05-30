//Winery
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

// Open Zeppelin libraries for controlling upgradability and access.
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./Vintner.sol";
import "./Upgrade.sol";
import "./VintageWine.sol";

interface IWineryProgression {
    function getFatigueSkillModifier(address owner) external view returns (uint256);
    function getBurnSkillModifier(address owner) external view returns (uint256);
    function getCellarSkillModifier(address owner) external view returns (uint256);
    function getMasterVintnerSkillModifier(address owner, uint256 masterVintnerNumber) external view returns (uint256);
    function getMaxLevelUpgrade(address owner) external view returns (uint256);
    function getMaxNumberVintners(address owner) external view returns (uint256);
    // function getMafiaModifier(address owner) external view returns (uint256);
    function getVintageWineStorage(address owner) external view returns (uint256);
}

// interface IMafia {
//     function mafiaIsActive() external view returns (bool);
//     function mafiaCurrentPenalty() external view returns (uint256);
// }

contract Winery is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    // Constants
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant CLAIM_VINTAGEWINE_CONTRIBUTION_PERCENTAGE = 10;
    uint256 public constant CLAIM_VINTAGEWINE_BURN_PERCENTAGE = 10;
    uint256 public constant MAX_FATIGUE = 100000000000000;

    // Staking

    mapping(uint256 => address) public stakedVintners; // tokenId => owner

    mapping(address => uint256) public fatiguePerMinute; // address => fatigue per minute in the winery
    mapping(address => uint256) public wineryFatigue; // address => fatigue
    mapping(address => uint256) public wineryVintageWine; // address => vintageWine
    mapping(address => uint256) public totalPPM; // address => total PPM
    mapping(address => uint256) public startTimeStamp; // address => startTimeStamp

    mapping(address => uint256[2]) public numberOfStaked; // address => [number of vintners, number of master vintners]

    mapping(uint256 => address) public stakedUpgrades; // tokenId => owner

    // Enumeration
    mapping(address => mapping(uint256 => uint256)) public ownedVintnerStakes; // (address, index) => tokenid
    mapping(uint256 => uint256) public ownedVintnerStakesIndex; // tokenId => index in its owner's stake list
    mapping(address => uint256) public ownedVintnerStakesBalance; // address => stake count

    mapping(address => mapping(uint256 => uint256)) public ownedUpgradeStakes; // (address, index) => tokenid
    mapping(uint256 => uint256) public ownedUpgradeStakesIndex; // tokenId => index in its owner's stake list
    mapping(address => uint256) public ownedUpgradeStakesBalance; // address => stake count

    // Fatigue cooldowns
    mapping(uint256 => uint256) public restingVintners; // tokenId => timestamp until rested. 0 if is not resting

    // Var

    uint256 public yieldPPS; // vintageWine cooked per second per unit of yield

    uint256 public startTime;

    uint256 public grapeResetCost; // 0.1 Grape is the cost per PPM

    uint256 public unstakePenalty; // Everytime someone unstake they need to pay this tax from the unclaimed amount

    uint256 public fatigueTuner;

    Vintner public vintner;
    Upgrade public upgrade;
    VintageWine public vintageWine;
    IGrape public grape;
    address public cellarAddress;
    IWineryProgression public wineryProgression;
    // IMafia public mafia;
    // address public mafiaAddress;

    function initialize(Vintner _vintner, Upgrade _upgrade, VintageWine _vintageWine, address _grape, address _cellarAddress, address _wineryProgression) public initializer {
        vintner = _vintner;
        grape = IGrape(_grape);
        upgrade = _upgrade;
        vintageWine = _vintageWine;
        cellarAddress = _cellarAddress;
        wineryProgression = IWineryProgression(_wineryProgression);

        yieldPPS = 16666666666666667; // vintageWine cooked per second per unit of yield
        startTime;
        grapeResetCost = 1e17; // 0.1 Grape is the cost per PPM
        unstakePenalty = 2000 * 1e18; // Everytime someone unstake they need to pay this tax from the unclaimed amount
        fatigueTuner = 100;

      ///@dev as there is no constructor, we need to initialise the OwnableUpgradeable explicitly
       __Ownable_init();
    }
    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}


    // Setters
    function setVintageWine(VintageWine _vintageWine) external onlyOwner {
        vintageWine = _vintageWine;
    }
    function setCellarAddress(address _cellarAddress) external onlyOwner {
        cellarAddress = _cellarAddress;
    }
    function setVintner(Vintner _vintner) external onlyOwner {
        vintner = _vintner;
    }
    function setUpgrade(Upgrade _upgrade) external onlyOwner {
        upgrade = _upgrade;
    }
    function setYieldPPS(uint256 _yieldPPS) external onlyOwner {
        yieldPPS = _yieldPPS;
    }
    function setGrapeResetCost(uint256 _grapeResetCost) external onlyOwner {
        grapeResetCost = _grapeResetCost;
    }
    function setUnstakePenalty(uint256 _unstakePenalty) external onlyOwner {
        unstakePenalty = _unstakePenalty;
    }
    function setFatigueTuner(uint256 _fatigueTuner) external onlyOwner {
        fatigueTuner = _fatigueTuner;
    }
    
    function setGrape(address _grape) external onlyOwner {
        grape = IGrape(_grape);
    }
    function setWineryProgression(address _wineryProgression) external onlyOwner {
        wineryProgression = IWineryProgression(_wineryProgression);
    }
    // function setMafia(address _mafia) external onlyOwner {
    //     mafiaAddress = _mafia;
    //     mafia = IMafia(_mafia);
    // }
    // Calculations

    /**
     * Updates the Fatigue per Minute
     * This function is called in _updateState
     */

    function fatiguePerMinuteCalculation(uint256 _ppm) public pure returns (uint256) {
        // NOTE: fatiguePerMinute[_owner] = 8610000000 + 166000000  * totalPPM[_owner] + -220833 * totalPPM[_owner]* totalPPM[_owner]  + 463 * totalPPM[_owner]*totalPPM[_owner]*totalPPM[_owner]; 
        uint256 a = 463;
        uint256 b = 220833;
        uint256 c = 166000000;
        uint256 d = 8610000000;
        if(_ppm == 0){
            return 0;
        }
        return d + c * _ppm + a * _ppm * _ppm * _ppm - b * _ppm * _ppm;
    }

    /**
     * Returns the timestamp of when the entire winery will be fatigued
     */
    function timeUntilFatiguedCalculation(uint256 _startTime, uint256 _fatigue, uint256 _fatiguePerMinute) public pure returns (uint256) {
        if(_fatiguePerMinute == 0){
            return _startTime + 31536000; // 1 year in seconds, arbitrary long duration
        }
        return _startTime + 60 * ( MAX_FATIGUE - _fatigue ) / _fatiguePerMinute;
    }

    /**
     * Returns the timestamp of when the vintner will be fully rested
     */
     function restingTimeCalculation(uint256 _vintnerType, uint256 _masterVintnerType, uint256 _fatigue) public pure returns (uint256) {
        uint256 maxTime = 43200; //12*60*60
        if( _vintnerType == _masterVintnerType){
            maxTime = maxTime / 2; // master vintners rest half of the time of regular vintners
        }

        if(_fatigue > MAX_FATIGUE / 2){
            return maxTime * _fatigue / MAX_FATIGUE;
        }

        return maxTime / 2; // minimum rest time is half of the maximum time
    }

    /**
     * Returns vintner's vintageWine from vintnerVintageWine mapping
     */
     function vintageWineAccruedCalculation(uint256 _initialVintageWine, uint256 _deltaTime, uint256 _ppm, uint256 _modifier, uint256 _fatigue, uint256 _fatiguePerMinute, uint256 _yieldPPS) public pure returns (uint256) {
        if(_fatigue >= MAX_FATIGUE){
            return _initialVintageWine;
        }

        uint256 a = _deltaTime * _ppm * _yieldPPS * _modifier * (MAX_FATIGUE - _fatigue) / ( 100 * MAX_FATIGUE);
        uint256 b = _deltaTime * _deltaTime * _ppm * _yieldPPS * _modifier * _fatiguePerMinute / (100 * 2 * 60 * MAX_FATIGUE);
        if(a > b){
            return _initialVintageWine + a - b;
        }

        return _initialVintageWine;
    }

    // Views

    function getFatiguePerMinuteWithModifier(address _owner) public view returns (uint256) {
        uint256 fatigueSkillModifier = wineryProgression.getFatigueSkillModifier(_owner);
        return fatiguePerMinute[_owner]* (fatigueSkillModifier/100) * (fatigueTuner/100);
    }

    function _getMasterVintnerNumber(address _owner) internal view returns (uint256) {
        return numberOfStaked[_owner][1];
    }

    /**
     * Returns the current vintner's fatigue
     */
    function getFatigueAccrued(address _owner) public view returns (uint256) {
        uint256 fatigue = (block.timestamp - startTimeStamp[_owner]) * getFatiguePerMinuteWithModifier(_owner) / 60;
        fatigue += wineryFatigue[_owner];
        if (fatigue > MAX_FATIGUE) {
            fatigue = MAX_FATIGUE;
        }
        return fatigue;
    }

    function getTimeUntilFatigued(address _owner) public view returns (uint256) {
        return timeUntilFatiguedCalculation(startTimeStamp[_owner], wineryFatigue[_owner], getFatiguePerMinuteWithModifier(_owner));
    }

    function getRestingTime(uint256 _tokenId, address _owner) public view returns (uint256) {
        return restingTimeCalculation(vintner.getType(_tokenId), vintner.MASTER_VINTNER_TYPE(), getFatigueAccrued(_owner));
    }

    function getVintageWineAccrued(address _owner) public view returns (uint256) {
        // if fatigueLastUpdate = MAX_FATIGUE it means that wineryVintageWine already has the correct value for the vintageWine, since it didn't produce vintageWine since last update
        uint256 fatigueLastUpdate = wineryFatigue[_owner];
        if(fatigueLastUpdate == MAX_FATIGUE){
            return wineryVintageWine[_owner];
        }

        uint256 timeUntilFatigued = getTimeUntilFatigued(_owner);

        uint256 endTimestamp;
        if(block.timestamp >= timeUntilFatigued){
            endTimestamp = timeUntilFatigued;
        } else {
            endTimestamp = block.timestamp;
        }

        uint256 ppm = getTotalPPM(_owner);

        uint256 masterVintnerSkillModifier = wineryProgression.getMasterVintnerSkillModifier(_owner, _getMasterVintnerNumber(_owner));

        uint256 delta = endTimestamp - startTimeStamp[_owner];

        uint256 newVintageWineAmount = vintageWineAccruedCalculation(wineryVintageWine[_owner], delta, ppm, masterVintnerSkillModifier, fatigueLastUpdate, getFatiguePerMinuteWithModifier(_owner), yieldPPS);

        uint256 maxVintageWine = wineryProgression.getVintageWineStorage(_owner);

        if(newVintageWineAmount > maxVintageWine){
            return maxVintageWine;
        }
        return newVintageWineAmount;
    }

    /**
     * Calculates the total PPM staked for a winery. 
     * This will also be used in the fatiguePerMinute calculation
     */
    function getTotalPPM(address _owner) public view returns (uint256) {
        return totalPPM[_owner];
    }

    function _updatefatiguePerMinute(address _owner) internal {
        uint256 ppm = totalPPM[_owner];
        if(ppm == 0){
            delete wineryFatigue[_owner];
        }
        fatiguePerMinute[_owner] = fatiguePerMinuteCalculation(ppm);
    }

    //Claim
    function _claimVintageWine(address _owner) internal {
        uint256 cellarSkillModifier = wineryProgression.getCellarSkillModifier(_owner);
        uint256 burnSkillModifier = wineryProgression.getBurnSkillModifier(_owner);

        uint256 totalClaimed = getVintageWineAccrued(_owner);

        delete wineryVintageWine[_owner];

        wineryFatigue[_owner] = getFatigueAccrued(_owner);

        startTimeStamp[_owner] = block.timestamp;

        uint256 taxAmountCellar = totalClaimed * (CLAIM_VINTAGEWINE_CONTRIBUTION_PERCENTAGE - cellarSkillModifier) / 100;
        uint256 taxAmountBurn = totalClaimed * (CLAIM_VINTAGEWINE_BURN_PERCENTAGE - burnSkillModifier) / 100;

        // uint256 taxAmountMafia = 0;
        // if(mafiaAddress != address(0) && mafia.mafiaIsActive()){
        //     uint256 mafiaSkillModifier = wineryProgression.getMafiaModifier(_owner);
        //     uint256 penalty = mafia.mafiaCurrentPenalty();
        //     if(penalty < mafiaSkillModifier){
        //         taxAmountMafia = 0;
        //     } else {
        //         taxAmountMafia = totalClaimed * (penalty - mafiaSkillModifier) / 100;
        //     }
        // }

        // totalClaimed = totalClaimed - taxAmountCellar - taxAmountBurn - taxAmountMafia;
        totalClaimed = totalClaimed - taxAmountCellar - taxAmountBurn;

        vintageWine.mint(_owner, totalClaimed);
        vintageWine.mint(cellarAddress, taxAmountCellar);
    }

    function claimVintageWine() public {
        address owner = msg.sender;
        _claimVintageWine(owner);
    }

    function _updateState(address _owner) internal {
        wineryVintageWine[_owner] = getVintageWineAccrued(_owner);

        wineryFatigue[_owner] = getFatigueAccrued(_owner);

        startTimeStamp[_owner] = block.timestamp;
    }

    //Resets fatigue and claims
    //Will need to approve grape first
    function resetFatigue() public {
        address _owner = msg.sender;
        uint256 ppm = getTotalPPM(_owner);
        uint256 costToReset = ppm * grapeResetCost;
        require(grape.balanceOf(_owner) >= costToReset, "not enough GRAPE");

        grape.transferFrom(address(_owner), DEAD_ADDRESS, costToReset);

        wineryVintageWine[_owner] = getVintageWineAccrued(_owner);
        startTimeStamp[_owner] = block.timestamp;
        delete wineryFatigue[_owner];
    }

    function _taxUnstake(address _owner, uint256 _taxableAmount) internal {
        uint256 totalClaimed = getVintageWineAccrued(_owner);
        uint256 penaltyCost = _taxableAmount * unstakePenalty;
        require(totalClaimed >= penaltyCost, "Not enough VintageWine to pay the unstake penalty.");

        wineryVintageWine[_owner] = totalClaimed - penaltyCost;

        wineryFatigue[_owner] = getFatigueAccrued(_owner);

        startTimeStamp[_owner] = block.timestamp;
    }


    function unstakeVintnersAndUpgrades(uint256[] calldata _vintnerIds, uint256[] calldata _upgradeIds) public {
        address owner = msg.sender;
        // Check 1:1 correspondency between vintner and upgrade
        require(numberOfStaked[owner][0] + numberOfStaked[owner][1] >= _vintnerIds.length, "Invalid number of vintners");
        require(ownedUpgradeStakesBalance[owner] >= _upgradeIds.length, "Invalid number of tools");
        require(numberOfStaked[owner][0] + numberOfStaked[owner][1] - _vintnerIds.length >= ownedUpgradeStakesBalance[owner] - _upgradeIds.length, "Needs at least vintner for each tool");

        uint256 upgradeLength = _upgradeIds.length;
        uint256 vintnerLength = _vintnerIds.length;

        _taxUnstake(owner, upgradeLength + vintnerLength);
        
        for (uint256 i = 0; i < upgradeLength; i++) { //unstake upgrades
            uint256 upgradeId = _upgradeIds[i];

            require(stakedUpgrades[upgradeId] == owner, "You don't own this tool");

            upgrade.transferFrom(address(this), owner, upgradeId);

            totalPPM[owner] -= upgrade.getYield(upgradeId);

            _removeUpgrade(upgradeId, owner);

        }

        for (uint256 i = 0; i < vintnerLength; i++) { //unstake vintners
            uint256 vintnerId = _vintnerIds[i];

            require(stakedVintners[vintnerId] == owner, "You don't own this token");
            require(restingVintners[vintnerId] == 0, "Vintner is resting");

            if(vintner.getType(vintnerId) == vintner.MASTER_VINTNER_TYPE()){
                numberOfStaked[owner][1]--; 
            } else {
                numberOfStaked[owner][0]--;
            }

            totalPPM[owner] -= vintner.getYield(vintnerId);

            _moveVintnerToCooldown(vintnerId, owner);
        }

        _updatefatiguePerMinute(owner);
    }

    // Stake

     /**
     * This function updates stake vintners and upgrades
     * The upgrades are paired with the vintner the upgrade will be applied
     */
    function stakeMany(uint256[] calldata _vintnerIds, uint256[] calldata _upgradeIds) public {
        require(gameStarted(), "The game has not started");

        address owner = msg.sender;

        uint256 maxNumberVintners = wineryProgression.getMaxNumberVintners(owner);
        uint256 vintnersAfterStaking = _vintnerIds.length + numberOfStaked[owner][0] + numberOfStaked[owner][1];
        require(maxNumberVintners >= vintnersAfterStaking, "You can't stake that many vintners");

        // Check 1:1 correspondency between vintner and upgrade
        require(vintnersAfterStaking >= ownedUpgradeStakesBalance[owner] + _upgradeIds.length, "Needs at least vintner for each tool");

        _updateState(owner);

        uint256 vintnerLength = _vintnerIds.length;
        for (uint256 i = 0; i < vintnerLength; i++) { //stakes vintner
            uint256 vintnerId = _vintnerIds[i];

            require(vintner.ownerOf(vintnerId) == owner, "You don't own this token");
            require(vintner.getType(vintnerId) > 0, "Vintner not yet revealed");

            if(vintner.getType(vintnerId) == vintner.MASTER_VINTNER_TYPE()){
                numberOfStaked[owner][1]++;
            } else {
                numberOfStaked[owner][0]++;
            }

            totalPPM[owner] += vintner.getYield(vintnerId);

            _addVintnerToWinery(vintnerId, owner);

            vintner.transferFrom(owner, address(this), vintnerId);
        }
        uint256 maxLevelUpgrade = wineryProgression.getMaxLevelUpgrade(owner);
        uint256 upgradeLength = _upgradeIds.length;
        for (uint256 i = 0; i < upgradeLength; i++) { //stakes upgrades
            uint256 upgradeId = _upgradeIds[i];

            require(upgrade.ownerOf(upgradeId) == owner, "You don't own this tool");
            require(upgrade.getLevel(upgradeId) <= maxLevelUpgrade, "You can't equip that tool");

            totalPPM[owner] += upgrade.getYield(upgradeId);

            _addUpgradeToWinery(upgradeId, owner);

            upgrade.transferFrom(owner, address(this), upgradeId);

        }
        _updatefatiguePerMinute(owner);
    }

    function withdrawVintners(uint256[] calldata _vintnerIds) public {
        address owner = msg.sender;
        uint256 vintnerLength = _vintnerIds.length;
        for (uint256 i = 0; i < vintnerLength; i++) {
            uint256 _vintnerId = _vintnerIds[i];

            require(restingVintners[_vintnerId] != 0, "Vintner is not resting");
            require(stakedVintners[_vintnerId] == owner, "You don't own this vintner");
            require(block.timestamp >= restingVintners[_vintnerId], "Vintner is still resting");

            _removeVintnerFromCooldown(_vintnerId, owner);

            vintner.transferFrom(address(this), owner, _vintnerId);
        }
    }

    function reStakeRestedVintners(uint256[] calldata _vintnerIds) public {
        address owner = msg.sender;

        uint256 maxNumberVintners = wineryProgression.getMaxNumberVintners(owner);
        uint256 vintnersAfterStaking = _vintnerIds.length + numberOfStaked[owner][0] + numberOfStaked[owner][1];
        require(maxNumberVintners >= vintnersAfterStaking, "You can't stake that many vintners");

        uint256 vintnerLength = _vintnerIds.length;
        for (uint256 i = 0; i < vintnerLength; i++) { //stakes vintner
            uint256 _vintnerId = _vintnerIds[i];

            require(restingVintners[_vintnerId] != 0, "Vintner is not resting");
            require(stakedVintners[_vintnerId] == owner, "You don't own this vintner");
            require(block.timestamp >= restingVintners[_vintnerId], "Vintner is still resting");

            delete restingVintners[_vintnerId];

            if(vintner.getType(_vintnerId) == vintner.MASTER_VINTNER_TYPE()){
                numberOfStaked[owner][1]++;
            } else {
                numberOfStaked[owner][0]++;
            }

            totalPPM[owner] += vintner.getYield(_vintnerId);
        }
        _updatefatiguePerMinute(owner);
    }

    function _addVintnerToWinery(uint256 _tokenId, address _owner) internal {
        stakedVintners[_tokenId] = _owner;
        uint256 length = ownedVintnerStakesBalance[_owner];
        ownedVintnerStakes[_owner][length] = _tokenId;
        ownedVintnerStakesIndex[_tokenId] = length;
        ownedVintnerStakesBalance[_owner]++;
    }

    function _addUpgradeToWinery(uint256 _tokenId, address _owner) internal {
        stakedUpgrades[_tokenId] = _owner;
        uint256 length = ownedUpgradeStakesBalance[_owner];
        ownedUpgradeStakes[_owner][length] = _tokenId;
        ownedUpgradeStakesIndex[_tokenId] = length;
        ownedUpgradeStakesBalance[_owner]++;
    }

    function _moveVintnerToCooldown(uint256 _vintnerId, address _owner) internal {
        uint256 endTimestamp = block.timestamp + getRestingTime(_vintnerId, _owner);
        restingVintners[_vintnerId] = endTimestamp;
    }

    function _removeVintnerFromCooldown(uint256 _vintnerId, address _owner) internal {
        delete restingVintners[_vintnerId];
        delete stakedVintners[_vintnerId];

        uint256 lastTokenIndex = ownedVintnerStakesBalance[_owner] - 1;
        uint256 tokenIndex = ownedVintnerStakesIndex[_vintnerId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedVintnerStakes[_owner][lastTokenIndex];

            ownedVintnerStakes[_owner][tokenIndex] = lastTokenId;
            ownedVintnerStakesIndex[lastTokenId] = tokenIndex;
        }

        delete ownedVintnerStakesIndex[_vintnerId];
        delete ownedVintnerStakes[_owner][lastTokenIndex];
        ownedVintnerStakesBalance[_owner]--;
    }

    function _removeUpgrade(uint256 _upgradeId, address _owner) internal {
        delete stakedUpgrades[_upgradeId];
        
        uint256 lastTokenIndex = ownedUpgradeStakesBalance[_owner] - 1;
        uint256 tokenIndex = ownedUpgradeStakesIndex[_upgradeId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedUpgradeStakes[_owner][lastTokenIndex];

            ownedUpgradeStakes[_owner][tokenIndex] = lastTokenId;
            ownedUpgradeStakesIndex[lastTokenId] = tokenIndex;
        }

        delete ownedUpgradeStakesIndex[_upgradeId];
        delete ownedUpgradeStakes[_owner][lastTokenIndex];
        ownedUpgradeStakesBalance[_owner]--;
    }

    // Admin

    function gameStarted() public view returns (bool) {
        return startTime != 0 && block.timestamp >= startTime;
    }

    function setStartTime(uint256 _startTime) external onlyOwner {
        require (_startTime >= block.timestamp, "startTime cannot be in the past");
        require(!gameStarted(), "game already started");
        startTime = _startTime;
    }

    // Aggregated views
    struct StakedVintnerInfo {
        uint256 vintnerId;
        uint256 vintnerPPM;
        bool isResting;
        uint256 endTimestamp;
    }

    function batchedStakesOfOwner(
        address _owner,
        uint256 _offset,
        uint256 _maxSize
    ) public view returns (StakedVintnerInfo[] memory) {
        if (_offset >= ownedVintnerStakesBalance[_owner]) {
            return new StakedVintnerInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= ownedVintnerStakesBalance[_owner]) {
            outputSize = ownedVintnerStakesBalance[_owner] - _offset;
        }
        StakedVintnerInfo[] memory outputs = new StakedVintnerInfo[](outputSize);

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 vintnerId = ownedVintnerStakes[_owner][_offset + i];

            outputs[i] = StakedVintnerInfo({
                vintnerId: vintnerId,
                vintnerPPM: vintner.getYield(vintnerId),
                isResting: restingVintners[vintnerId] > 0,
                endTimestamp: restingVintners[vintnerId]
            });
        }

        return outputs;
    }

    struct StakedToolInfo {
        uint256 toolId;
        uint256 toolPPM;
    }

    function batchedToolsOfOwner(
        address _owner,
        uint256 _offset,
        uint256 _maxSize
    ) public view returns (StakedToolInfo[] memory) {
        if (_offset >= ownedUpgradeStakesBalance[_owner]) {
            return new StakedToolInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= ownedUpgradeStakesBalance[_owner]) {
            outputSize = ownedUpgradeStakesBalance[_owner] - _offset;
        }
        StakedToolInfo[] memory outputs = new StakedToolInfo[](outputSize);

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 toolId = ownedUpgradeStakes[_owner][_offset + i];

            outputs[i] = StakedToolInfo({
                toolId: toolId,
                toolPPM: upgrade.getYield(toolId)
            });
        }

        return outputs;
    }

}