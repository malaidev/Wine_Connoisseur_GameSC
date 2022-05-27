//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VintageWine is ERC20("VintageWine", "VINTAGEWINE"), Ownable {
    uint256 public constant ONE_VINTAGEWINE = 1e18;
    uint256 public constant NUM_PROMOTIONAL_VINTAGEWINE = 500_000;
    uint256 public constant NUM_VINTAGEWINE_GRAPE_LP = 20_000_000;

    uint256 public NUM_VINTAGEWINE_AVAX_LP = 30_000_000;

    address public cellarAddress;
    address public wineryAddress;
    address public vintnerAddress;
    address public upgradeAddress;

    bool public promotionalVintageWineMinted = false;
    bool public avaxLPVintageWineMinted = false;
    bool public grapeLPVintageWineMinted = false;

    // ADMIN

    /**
     * winery yields vintageWine
     */
    function setWineryAddress(address _wineryAddress) external onlyOwner {
        wineryAddress = _wineryAddress;
    }

    function setCellarAddress(address _cellarAddress) external onlyOwner {
        cellarAddress = _cellarAddress;
    }

    function setUpgradeAddress(address _upgradeAddress) external onlyOwner {
        upgradeAddress = _upgradeAddress;
    }

    /**
     * vintner consumes vintageWine
     * vintner address can only be set once
     */
    function setVintnerAddress(address _vintnerAddress) external onlyOwner {
        require(address(vintnerAddress) == address(0), "vintner address already set");
        vintnerAddress = _vintnerAddress;
    }

    function mintPromotionalVintageWine(address _to) external onlyOwner {
        require(!promotionalVintageWineMinted, "promotional vintageWine has already been minted");
        promotionalVintageWineMinted = true;
        _mint(_to, NUM_PROMOTIONAL_VINTAGEWINE * ONE_VINTAGEWINE);
    }

    function mintAvaxLPVintageWine() external onlyOwner {
        require(!avaxLPVintageWineMinted, "avax vintageWine LP has already been minted");
        avaxLPVintageWineMinted = true;
        _mint(owner(), NUM_VINTAGEWINE_AVAX_LP * ONE_VINTAGEWINE);
    }

    function mintGrapeLPVintageWine() external onlyOwner {
        require(!grapeLPVintageWineMinted, "grape vintageWine LP has already been minted");
        grapeLPVintageWineMinted = true;
        _mint(owner(), NUM_VINTAGEWINE_GRAPE_LP * ONE_VINTAGEWINE);
    }

    function setNumVintageWineAvaxLp(uint256 _numVintageWineAvaxLp) external onlyOwner {
        NUM_VINTAGEWINE_AVAX_LP = _numVintageWineAvaxLp;
    }

    // external

    function mint(address _to, uint256 _amount) external {
        require(wineryAddress != address(0) && vintnerAddress != address(0) && cellarAddress != address(0) && upgradeAddress != address(0), "missing initial requirements");
        require(_msgSender() == wineryAddress,"msgsender does not have permission");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        require(vintnerAddress != address(0) && cellarAddress != address(0) && upgradeAddress != address(0), "missing initial requirements");
        require(
            _msgSender() == vintnerAddress 
            || _msgSender() == cellarAddress 
            || _msgSender() == upgradeAddress,
            "msgsender does not have permission"
        );
        _burn(_from, _amount);
    }

    function transferToCellar(address _from, uint256 _amount) external {
        require(cellarAddress != address(0), "missing initial requirements");
        require(_msgSender() == cellarAddress, "only the cellar contract can call transferToCellar");
        _transfer(_from, cellarAddress, _amount);
    }

    function transferForUpgradesFees(address _from, uint256 _amount) external {
        require(upgradeAddress != address(0), "missing initial requirements");
        require(_msgSender() == upgradeAddress, "only the upgrade contract can call transferForUpgradesFees");
        _transfer(_from, upgradeAddress, _amount);
    }
}