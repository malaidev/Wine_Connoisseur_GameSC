// Chef
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
// import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./VintageWine.sol";

contract Vintner is ERC721Enumerable, Ownable, Pausable {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    struct VintnerInfo {
        uint256 tokenId;
        uint256 vintnerType;
    }

    // CONSTANTS

    // uint256 public constant VINTNER_PRICE_WHITELIST = 1 ether;
    uint256 public constant VINTNER_PRICE_AVAX = 1.5 ether;

    // uint256 public constant WHITELIST_VINTNERS = 1000;
    uint256 public constant VINTNERS_PER_VINTAGEWINE_MINT_LEVEL = 5000;

    // uint256 public constant MAXIMUM_MINTS_PER_WHITELIST_ADDRESS = 4;

    uint256 public constant NUM_GEN0_VINTNERS = 10_000;
    uint256 public constant NUM_GEN1_VINTNERS = 10_000;

    uint256 public constant VINTNER_TYPE = 1;
    uint256 public constant MASTER_VINTNER_TYPE = 2;

    uint256 public constant VINTNER_YIELD = 1;
    uint256 public constant MASTER_VINTNER_YIELD = 3;

    uint256 public constant PROMOTIONAL_VINTNERS = 50;

    // VAR

    // external contracts
    VintageWine public vintageWine;
    address public wineryAddress;
    address public vintnerTypeOracleAddress;

    // metadata URI
    string public BASE_URI;

    // vintner type definitions (normal or master?)
    mapping(uint256 => uint256) public tokenTypes; // maps tokenId to its type
    mapping(uint256 => uint256) public typeYields; // maps vintner type to yield

    // mint tracking
    uint256 public vintnersMintedWithAVAX;
    uint256 public vintnersMintedWithVINTAGEWINE;
    // uint256 public vintnersMintedWhitelist;
    uint256 public vintnersMintedPromotional;
    uint256 public vintnersMinted = 50; // First 50 ids are reserved for the promotional vintners

    // mint control timestamps
    // uint256 public startTimeWhitelist;
    uint256 public startTimeAVAX;
    uint256 public startTimeVINTAGEWINE;

    // VINTAGEWINE mint price tracking
    uint256 public currentVINTAGEWINEMintCost = 20_000 * 1e18;

    // whitelist
    // bytes32 public merkleRoot;
    // mapping(address => uint256) public whitelistClaimed;

    // EVENTS

    event onVintnerCreated(uint256 tokenId);
    event onVintnerRevealed(uint256 tokenId, uint256 vintnerType);

    /**
     * requires vintageWine, vintnerType oracle address
     * vintageWine: for liquidity bootstrapping and spending on vintners
     * vintnerTypeOracleAddress: external vintner generator uses secure RNG
     */
    constructor(
        VintageWine _vintageWine,
        address _vintnerTypeOracleAddress,
        string memory _BASE_URI
    ) ERC721("VintageWine Game Vintners", "VINTAGEWINE-GAME-VINTNER") {
        require(address(_vintageWine) != address(0));
        require(_vintnerTypeOracleAddress != address(0));

        // set required contract references
        vintageWine = _vintageWine;
        vintnerTypeOracleAddress = _vintnerTypeOracleAddress;

        // set base uri
        BASE_URI = _BASE_URI;

        // initialize token yield values for each vintner type
        typeYields[VINTNER_TYPE] = VINTNER_YIELD;
        typeYields[MASTER_VINTNER_TYPE] = MASTER_VINTNER_YIELD;
    }

    // VIEWS

    // minting status

    // function mintingStartedWhitelist() public view returns (bool) {
    //     return startTimeWhitelist != 0 && block.timestamp >= startTimeWhitelist;
    // }

    function mintingStartedAVAX() public view returns (bool) {
        return startTimeAVAX != 0 && block.timestamp >= startTimeAVAX;
    }

    function mintingStartedVINTAGEWINE() public view returns (bool) {
        return
            startTimeVINTAGEWINE != 0 &&
            block.timestamp >= startTimeVINTAGEWINE;
    }

    // metadata

    function _baseURI() internal view virtual override returns (string memory) {
        return BASE_URI;
    }

    function getYield(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId), "token does not exist");
        return typeYields[tokenTypes[_tokenId]];
    }

    function getType(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId), "token does not exist");
        return tokenTypes[_tokenId];
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return
            string(
                abi.encodePacked(_baseURI(), "/", tokenId.toString(), ".json")
            );
    }

    // override

    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool)
    {
        // winery must be able to stake and unstake
        if (wineryAddress != address(0) && _operator == wineryAddress)
            return true;
        return super.isApprovedForAll(_owner, _operator);
    }

    // ADMIN

    function setWineryAddress(address _wineryAddress) external onlyOwner {
        wineryAddress = _wineryAddress;
    }

    function setVintageWine(address _vintageWine) external onlyOwner {
        vintageWine = VintageWine(_vintageWine);
    }

    function setvintnerTypeOracleAddress(address _vintnerTypeOracleAddress)
        external
        onlyOwner
    {
        vintnerTypeOracleAddress = _vintnerTypeOracleAddress;
    }

    // function setStartTimeWhitelist(uint256 _startTime) external onlyOwner {
    //     require(
    //         _startTime >= block.timestamp,
    //         "startTime cannot be in the past"
    //     );
    //     startTimeWhitelist = _startTime;
    // }

    function setStartTimeAVAX(uint256 _startTime) external onlyOwner {
        require(
            _startTime >= block.timestamp,
            "startTime cannot be in the past"
        );
        startTimeAVAX = _startTime;
    }

    function setStartTimeVINTAGEWINE(uint256 _startTime) external onlyOwner {
        require(
            _startTime >= block.timestamp,
            "startTime cannot be in the past"
        );
        startTimeVINTAGEWINE = _startTime;
    }

    function setBaseURI(string calldata _BASE_URI) external onlyOwner {
        BASE_URI = _BASE_URI;
    }

    /**
     * @dev merkle root for WL wallets
     */
    // function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
    //     merkleRoot = _merkleRoot;
    // }

    /**
     * @dev allows owner to send ERC20s held by this contract to target
     */
    function forwardERC20s(
        IERC20 _token,
        uint256 _amount,
        address target
    ) external onlyOwner {
        _token.safeTransfer(target, _amount);
    }

    /**
     * @dev allows owner to withdraw AVAX
     */
    function withdrawAVAX(uint256 _amount) external payable onlyOwner {
        require(address(this).balance >= _amount, "not enough AVAX");
        address payable to = payable(_msgSender());
        (bool sent, ) = to.call{ value: _amount }("");
        require(sent, "Failed to send AVAX");
    }

    // MINTING

    function _createVintner(address to, uint256 tokenId) internal {
        require(
            vintnersMinted <= NUM_GEN0_VINTNERS + NUM_GEN1_VINTNERS,
            "cannot mint anymore vintners"
        );
        _safeMint(to, tokenId);

        emit onVintnerCreated(tokenId);
    }

    function _createVintners(uint256 qty, address to) internal {
        for (uint256 i = 0; i < qty; i++) {
            vintnersMinted += 1;
            _createVintner(to, vintnersMinted);
        }
    }

    /**
     * @dev as an anti cheat mechanism, an external automation will generate the NFT metadata and set the vintner types via rng
     * - Using an external source of randomness ensures our mint cannot be cheated
     * - The external automation is open source and can be found on vintageWine game's github
     * - Once the mint is finished, it is provable that this randomness was not tampered with by providing the seed
     * - Vintner type can be set only once
     */
    function setVintnerType(uint256 tokenId, uint256 vintnerType) external {
        require(
            _msgSender() == vintnerTypeOracleAddress,
            "msgsender does not have permission"
        );
        require(
            tokenTypes[tokenId] == 0,
            "that token's type has already been set"
        );
        require(
            vintnerType == VINTNER_TYPE || vintnerType == MASTER_VINTNER_TYPE,
            "invalid vintner type"
        );

        tokenTypes[tokenId] = vintnerType;
        emit onVintnerRevealed(tokenId, vintnerType);
    }

    /**
     * @dev Promotional GEN0 minting
     * Can mint maximum of PROMOTIONAL_VINTNERS
     * All vintners minted are from the same vintnerType
     */
    function mintPromotional(
        uint256 qty,
        uint256 vintnerType,
        address target
    ) external onlyOwner {
        require(qty > 0, "quantity must be greater than 0");
        require(
            (vintnersMintedPromotional + qty) <= PROMOTIONAL_VINTNERS,
            "you can't mint that many right now"
        );
        require(
            vintnerType == VINTNER_TYPE || vintnerType == MASTER_VINTNER_TYPE,
            "invalid vintner type"
        );

        for (uint256 i = 0; i < qty; i++) {
            vintnersMintedPromotional += 1;
            require(
                tokenTypes[vintnersMintedPromotional] == 0,
                "that token's type has already been set"
            );
            tokenTypes[vintnersMintedPromotional] = vintnerType;
            _createVintner(target, vintnersMintedPromotional);
        }
    }

    /**
     * @dev Whitelist GEN0 minting
     * We implement a hard limit on the whitelist vintners.
     */
    // function mintWhitelist(bytes32[] calldata _merkleProof, uint256 qty)
    //     external
    //     payable
    //     whenNotPaused
    // {
    //     // check most basic requirements
    //     require(merkleRoot != 0, "missing root");
    //     require(mintingStartedWhitelist(), "cannot mint right now");
    //     require(!mintingStartedAVAX(), "whitelist minting is closed");

    //     // check if address belongs in whitelist
    //     bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
    //     require(
    //         MerkleProof.verify(_merkleProof, merkleRoot, leaf),
    //         "this address does not have permission"
    //     );

    //     // check more advanced requirements
    //     require(
    //         qty > 0 && qty <= MAXIMUM_MINTS_PER_WHITELIST_ADDRESS,
    //         "quantity must be between 1 and 4"
    //     );
    //     require(
    //         (vintnersMintedWhitelist + qty) <= WHITELIST_VINTNERS,
    //         "you can't mint that many right now"
    //     );
    //     require(
    //         (whitelistClaimed[_msgSender()] + qty) <=
    //             MAXIMUM_MINTS_PER_WHITELIST_ADDRESS,
    //         "this address can't mint any more whitelist vintners"
    //     );

    //     // check price
    //     require(msg.value >= VINTNER_PRICE_WHITELIST * qty, "not enough AVAX");

    //     vintnersMintedWhitelist += qty;
    //     whitelistClaimed[_msgSender()] += qty;

    //     // mint vintners
    //     _createVintners(qty, _msgSender());
    // }

    /**
     * @dev GEN0 minting
     */
    function mintVintnerWithAVAX(uint256 qty) external payable whenNotPaused {
        require(mintingStartedAVAX(), "cannot mint right now");
        require(qty > 0 && qty <= 10, "quantity must be between 1 and 10");
        require(
            (vintnersMintedWithAVAX + qty) <=
                (NUM_GEN0_VINTNERS -
                    // vintnersMintedWhitelist -
                    PROMOTIONAL_VINTNERS),
            "you can't mint that many right now"
        );

        // calculate the transaction cost
        uint256 transactionCost = VINTNER_PRICE_AVAX * qty;
        require(msg.value >= transactionCost, "not enough AVAX");

        vintnersMintedWithAVAX += qty;

        // mint vintners
        _createVintners(qty, _msgSender());
    }

    /**
     * @dev GEN1 minting
     */
    function mintVintnerWithVINTAGEWINE(uint256 qty) external whenNotPaused {
        require(mintingStartedVINTAGEWINE(), "cannot mint right now");
        require(qty > 0 && qty <= 10, "quantity must be between 1 and 10");
        require(
            (vintnersMintedWithVINTAGEWINE + qty) <= NUM_GEN1_VINTNERS,
            "you can't mint that many right now"
        );

        // calculate transaction costs
        uint256 transactionCostVINTAGEWINE = currentVINTAGEWINEMintCost * qty;
        require(
            vintageWine.balanceOf(_msgSender()) >= transactionCostVINTAGEWINE,
            "not enough VINTAGEWINE"
        );

        // raise the mint level and cost when this mint would place us in the next level
        // if you mint in the cost transition you get a discount =)
        if (
            vintnersMintedWithVINTAGEWINE <=
            VINTNERS_PER_VINTAGEWINE_MINT_LEVEL &&
            vintnersMintedWithVINTAGEWINE + qty >
            VINTNERS_PER_VINTAGEWINE_MINT_LEVEL
        ) {
            currentVINTAGEWINEMintCost = currentVINTAGEWINEMintCost * 2;
        }

        vintnersMintedWithVINTAGEWINE += qty;

        // spend vintageWine
        vintageWine.burn(_msgSender(), transactionCostVINTAGEWINE);

        // mint vintners
        _createVintners(qty, _msgSender());
    }

    // Returns information for multiples vintners
    function batchedVintnersOfOwner(
        address _owner,
        uint256 _offset,
        uint256 _maxSize
    ) public view returns (VintnerInfo[] memory) {
        if (_offset >= balanceOf(_owner)) {
            return new VintnerInfo[](0);
        }

        uint256 outputSize = _maxSize;
        if (_offset + _maxSize >= balanceOf(_owner)) {
            outputSize = balanceOf(_owner) - _offset;
        }
        VintnerInfo[] memory vintners = new VintnerInfo[](outputSize);

        for (uint256 i = 0; i < outputSize; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, _offset + i); // tokenOfOwnerByIndex comes from IERC721Enumerable

            vintners[i] = VintnerInfo({
                tokenId: tokenId,
                vintnerType: tokenTypes[tokenId]
            });
        }

        return vintners;
    }
}
