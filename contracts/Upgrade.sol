//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./VintageWine.sol";
import "./Grape.sol";

contract Upgrade is ERC721Enumerable, Ownable, Pausable {
    using SafeERC20 for IERC20;
    using Strings for uint256;


    struct UpgradeInfo {
        uint256 tokenId;
        uint256 level;
        uint256 yield;
    }
    // Struct

    struct Level {
        uint256 supply;
        uint256 maxSupply;
        uint256 priceVintageWine;
        uint256 priceGrape;
        uint256 yield;
    }

    // Var

    VintageWine vintageWine;
    Grape grape;
    address public wineryAddress;

    string public BASE_URI;

    uint256 public startTime;

    mapping(uint256 => Level) public levels;
    uint256 currentLevelIndex;

    uint256 public upgradesMinted = 0;

    uint256 public constant LP_TAX_PERCENT = 2;

    mapping(uint256 => uint256) private tokenLevel;

    // Events

    event onUpgradeCreated(uint256 level);

    // Constructor

    constructor(VintageWine _vintageWine, Grape _grape, string memory _BASE_URI) ERC721("VintageWine Game Vintner Tools", "VINTAGEWINE-GAME-VINTNER-TOOL") {
        vintageWine = _vintageWine;
        grape = _grape;
        BASE_URI = _BASE_URI;
        
        // first three upgrades
        levels[0] = Level({ supply: 0, maxSupply: 2500, priceVintageWine: 3000 * 1e18, priceGrape: 50 * 1e18, yield: 1 });
        levels[1] = Level({ supply: 0, maxSupply: 2200, priceVintageWine: 10000 * 1e18, priceGrape: 80 * 1e18, yield: 3 });
        levels[2] = Level({ supply: 0, maxSupply: 2000, priceVintageWine: 20000 * 1e18, priceGrape: 110 * 1e18, yield: 5 });
        currentLevelIndex = 2;
    }

    // Views

    function mintingStarted() public view returns (bool) {
        return startTime != 0 && block.timestamp > startTime;
    }

    function getYield(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId), "token does not exist");
        return levels[tokenLevel[_tokenId]].yield;
    }

    function getLevel(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId), "token does not exist");
        return tokenLevel[_tokenId];
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return BASE_URI;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        uint256 levelFixed = tokenLevel[_tokenId] + 1;
        return string(abi.encodePacked(_baseURI(), "/", levelFixed.toString(), ".json"));
    }

    function isApprovedForAll(address _owner, address _operator) public view override returns (bool) {
        if (wineryAddress != address(0) && _operator == wineryAddress) return true;
        return super.isApprovedForAll(_owner, _operator);
    }

    // ADMIN

    function addLevel(uint256 _maxSupply, uint256 _priceVintageWine, uint256 _priceGrape, uint256 _yield) external onlyOwner {
        currentLevelIndex++;
        levels[currentLevelIndex] = Level({ supply: 0, maxSupply: _maxSupply, priceVintageWine: _priceVintageWine, priceGrape: _priceGrape, yield: _yield });
    }

    function changeLevel(uint256 _index, uint256 _maxSupply, uint256 _priceVintageWine, uint256 _priceGrape, uint256 _yield) external onlyOwner {
        require(_index <= currentLevelIndex, "invalid level");
        levels[_index] = Level({ supply: 0, maxSupply: _maxSupply, priceVintageWine: _priceVintageWine, priceGrape: _priceGrape, yield: _yield });
    }

    function setVintageWine(VintageWine _vintageWine) external onlyOwner {
        vintageWine = _vintageWine;
    }

    function setGrape(Grape _grape) external onlyOwner {
        grape = _grape;
    }

    function setWineryAddress(address _wineryAddress) external onlyOwner {
        wineryAddress = _wineryAddress;
    }

    function setStartTime(uint256 _startTime) external onlyOwner {
        require(_startTime > block.timestamp, "startTime must be in future");
        require(!mintingStarted(), "minting already started");
        startTime = _startTime;
    }

    function setBaseURI(string calldata _BASE_URI) external onlyOwner {
        BASE_URI = _BASE_URI;
    }

    function forwardERC20s(IERC20 _token, uint256 _amount, address target) external onlyOwner {
        _token.safeTransfer(target, _amount);
    }

    // Minting

    function _createUpgrades(uint256 qty, uint256 level, address to) internal {
        for (uint256 i = 0; i < qty; i++) {
            upgradesMinted += 1;
            levels[level].supply += 1;
            tokenLevel[upgradesMinted] = level;
            _safeMint(to, upgradesMinted);
            emit onUpgradeCreated(level);
        }
    }

    function mintUpgrade(uint256 _level, uint256 _qty) external whenNotPaused {
        require(mintingStarted(), "Tools sales are not open");
        require (_qty > 0 && _qty <= 10, "quantity must be between 1 and 10");
        require(_level <= currentLevelIndex, "invalid level");
        require ((levels[_level].supply + _qty) <= levels[_level].maxSupply, "you can't mint that many right now");

        uint256 transactionCostVintageWine = levels[_level].priceVintageWine * _qty;
        uint256 transactionCostGrape = levels[_level].priceGrape * _qty;
        require (vintageWine.balanceOf(_msgSender()) >= transactionCostVintageWine, "not have enough VINTAGEWINE");
        require (grape.balanceOf(_msgSender()) >= transactionCostGrape, "not have enough GRAPE");

        _createUpgrades(_qty, _level, _msgSender());

        vintageWine.burn(_msgSender(), transactionCostVintageWine * (100 - LP_TAX_PERCENT) / 100);
        grape.burn(_msgSender(), transactionCostGrape * (100 - LP_TAX_PERCENT) / 100);

        vintageWine.transferForUpgradesFees(_msgSender(), transactionCostVintageWine * LP_TAX_PERCENT / 100);
        grape.transferForUpgradesFees(_msgSender(), transactionCostGrape * LP_TAX_PERCENT / 100);
    }

    // Returns information for multiples upgrades
    function batchedUpgradesOfOwner(address _owner, uint256 _offset, uint256 _maxSize) public view returns (UpgradeInfo[] memory) {
        if (_offset >= balanceOf(_owner)) {
            return new UpgradeInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= balanceOf(_owner)) {
            outputSize = balanceOf(_owner) - _offset;
        }
        UpgradeInfo[] memory upgrades = new UpgradeInfo[](outputSize);

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, _offset + i); // tokenOfOwnerByIndex comes from IERC721Enumerable

            upgrades[i] = UpgradeInfo({
                tokenId: tokenId,
                level: tokenLevel[tokenId],
                yield: levels[tokenLevel[tokenId]].yield
            });
        }
        return upgrades;
    }

}
