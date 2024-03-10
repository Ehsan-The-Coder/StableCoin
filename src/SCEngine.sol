// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//<----------------------------import statements---------------------------->
import {Utilis} from "./Libraries/Utilis.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StableCoin} from "./StableCoin.sol";
import {ChainlinkManager} from "./libraries/ChainlinkManager.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {console} from "forge-std/Script.sol";

contract SCEngine is ReentrancyGuard {
    //<----------------------------type declarations---------------------------->

    //<----------------------------state variable---------------------------->
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10;

    mapping(address token => address priceFeed) private s_tokenPriceFeed;
    address[] private s_tokens;
    mapping(address depositer => mapping(address tokenCollateralAddress => uint balance))
        private s_collateralDeposited;
    mapping(address minter => uint256 balance) private s_scMinted;
    address private immutable i_stableCoin;

    //<----------------------------events---------------------------->
    event CollataralDeposited(
        address indexed depositer,
        address indexed tokenCollateralAddress,
        uint256 quantity
    );
    event CollateralRedeemed(
        address indexed from,
        address indexed to,
        address indexed tokenCollateralAddress,
        uint256 amountCollateral
    );
    //<----------------------------custom errors---------------------------->
    error SCEngine__LengthOfConstructorValuesNotEqual(
        uint256 tokenLength,
        uint256 priceFeedLength
    );
    error SCEngine__ZeroAddress();
    error SCEngine__ZeroValue();
    error SCEngine__IdenticalTokenAndPriceFeed();
    error SCEngine__TokenNotListed(address token);
    error SCEngine__TokenTransferFromFailed();
    error SCEngine__TransferFailed();
    error SCEngine__TokenMintFailed();
    error SCEngine__BreaksHealthFactor(uint256 userHealthFactor);
    error SCEngine__HealthFactorOk();
    error SCEngine__HealthFactorNotImproved();
    //<----------------------------modifiers---------------------------->
    modifier notEqualLength(uint256 lengthA, uint256 lengthB) {
        if (lengthA != lengthB) {
            revert SCEngine__LengthOfConstructorValuesNotEqual(
                lengthA,
                lengthB
            );
        }
        _;
    }

    modifier isTokenExisted(address token) {
        if (s_tokenPriceFeed[token] == address(0)) {
            revert SCEngine__TokenNotListed(token);
        }
        _;
    }
    modifier isValueZero(uint256 quantity) {
        if (quantity == 0) {
            revert SCEngine__ZeroValue();
        }
        _;
    }

    //<----------------------------functions---------------------------->
    //<----------------------------constructor---------------------------->
    constructor(
        address[] memory token,
        address[] memory priceFeed,
        address stableCoin
    )
        notEqualLength(token.length, priceFeed.length)
        isValueZero(token.length)
        isValueZero(priceFeed.length)
    {
        for (uint256 index = 0; index < token.length; index++) {
            address _token = token[index];
            address _priceFeed = priceFeed[index];

            _revertZeroAddress(_token);
            _revertZeroAddress(_priceFeed);
            _reverIdenticalAddress(_token, _priceFeed);

            s_tokenPriceFeed[_token] = _priceFeed;
            s_tokens.push(_token);
        }

        _revertZeroAddress(stableCoin);
        i_stableCoin = stableCoin;
    }

    //<----------------------------external functions---------------------------->
    function depositCollataralAndMintSc(
        address tokenCollateralAddress,
        uint256 quantity,
        uint256 mintQuantity
    ) external {
        depositCollataral(tokenCollateralAddress, quantity);
        mintSc(mintQuantity);
    }

    function redeemCollateralForSc(
        address token,
        uint256 quantityOfCollateral,
        uint256 quantityToBurn
    )
        external
        isValueZero(quantityOfCollateral)
        isValueZero(quantityToBurn)
        isTokenExisted(token)
    {
        _burnSc(quantityToBurn, msg.sender, msg.sender);
        _redeemCollateral(token, quantityOfCollateral, msg.sender, msg.sender);
    }

    function redeemCollateral(
        address token,
        uint256 quantity
    ) external isValueZero(quantity) nonReentrant isTokenExisted(token) {
        _redeemCollateral(token, quantity, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnSc(uint256 quantity) external isValueZero(quantity) {
        _burnSc(quantity, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // I don't think this would ever hit...
    }

    function liquidate(
        address token,
        address user,
        uint256 debtToCover
    ) external isValueZero(debtToCover) nonReentrant {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert SCEngine__HealthFactorOk();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(
            token,
            debtToCover
        );
        uint256 bonusCollateral = (tokenAmountFromDebtCovered *
            LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        _redeemCollateral(
            token,
            tokenAmountFromDebtCovered + bonusCollateral,
            user,
            msg.sender
        );
        _burnSc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert SCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    //<----------------------------public functions---------------------------->

    function depositCollataral(
        address tokenCollateralAddress,
        uint256 quantity
    )
        public
        isTokenExisted(tokenCollateralAddress)
        isValueZero(quantity)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += quantity;
        emit CollataralDeposited(msg.sender, tokenCollateralAddress, quantity);
        bool isSuccess = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            quantity
        );
        if (isSuccess == false) {
            revert SCEngine__TokenTransferFromFailed();
        }
    }

    function mintSc(
        uint256 quantity
    ) public isValueZero(quantity) nonReentrant {
        s_scMinted[msg.sender] += quantity;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool isSuccess = StableCoin(i_stableCoin).mint(msg.sender, quantity);
        if (isSuccess == false) {
            revert SCEngine__TokenMintFailed();
        }
    }

    //<----------------------------external/public view/pure functions---------------------------->
    function getTokenAmountFromUsd(
        address token,
        uint256 usdAmountInWei
    ) public view isTokenExisted(token) returns (uint256) {
        uint256 price = ChainlinkManager.getPrice(s_tokenPriceFeed[token]);
        return ((usdAmountInWei * PRECISION) / price);
    }

    function getUserHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function calculateUserHealthFactor(
        uint256 totalScMinted,
        uint256 collateralValueInUsd
    ) external pure returns (uint256) {
        return _calculateHealthFactor(totalScMinted, collateralValueInUsd);
    }

    function getAccountInformation(
        address user
    )
        external
        view
        returns (uint256 totalScMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    function getStableCoin() external view returns (address) {
        return i_stableCoin;
    }

    function getTokens() external view returns (address[] memory) {
        return s_tokens;
    }

    function getPriceFeed(
        address token
    ) external view returns (address priceFeed) {
        return s_tokenPriceFeed[token];
    }

    function getPrice(address priceFeed) external view returns (uint256) {
        return ChainlinkManager.getPrice(priceFeed);
    }

    function getTotalAmount(
        address priceFeed,
        uint256 quantity
    ) external view returns (uint256) {
        return ChainlinkManager.getTotalAmount(priceFeed, quantity);
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getMinimumHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getDepositerCollateralBalance(
        address depositer,
        address tokenCollateralAddress
    ) external view returns (uint256) {
        return s_collateralDeposited[depositer][tokenCollateralAddress];
    }

    function getMinterMintBalance(
        address minter
    ) external view returns (uint256) {
        return s_scMinted[minter];
    }

    //<----------------------------private functions---------------------------->
    function _redeemCollateral(
        address tokenCollateralAddress,
        uint256 quantity,
        address from,
        address to
    ) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= quantity;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, quantity);
        bool success = IERC20(tokenCollateralAddress).transfer(to, quantity);
        if (!success) {
            revert SCEngine__TransferFailed();
        }
    }

    function _burnSc(
        uint256 quantity,
        address onBehalfOf,
        address scFrom
    ) private {
        s_scMinted[onBehalfOf] -= quantity;

        bool success = StableCoin(i_stableCoin).transferFrom(
            scFrom,
            address(this),
            quantity
        );
        if (!success) {
            revert SCEngine__TransferFailed();
        }

        StableCoin(i_stableCoin).burn(quantity);
    }

    //<----------------------------private view/pure functions---------------------------->

    function _healthFactor(address user) private view returns (uint256) {
        (
            uint256 totalScMinted,
            uint256 collateralValueInUsd
        ) = _getAccountInformation(user);
        return _calculateHealthFactor(totalScMinted, collateralValueInUsd);
    }

    function _calculateHealthFactor(
        uint256 totalScMinted,
        uint256 collateralValueInUsd
    ) private pure returns (uint256) {
        if (totalScMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalScMinted;
    }

    function _getAccountInformation(
        address user
    )
        private
        view
        returns (uint256 totalScMinted, uint256 collateralValueInUsd)
    {
        totalScMinted = s_scMinted[user];
        for (uint256 index = 0; index < s_tokens.length; index++) {
            address token = s_tokens[index];
            uint256 quantity = s_collateralDeposited[user][token];

            address priceFeed = s_tokenPriceFeed[token];
            collateralValueInUsd += ChainlinkManager.getTotalAmount(
                priceFeed,
                quantity
            );
        }
        return (totalScMinted, collateralValueInUsd);
    }

    function _revertIfHealthFactorIsBroken(address user) private view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert SCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _revertZeroAddress(address _address) private pure {
        if (_address == address(0)) {
            revert SCEngine__ZeroAddress();
        }
    }

    function _reverIdenticalAddress(
        address _addressA,
        address _addressB
    ) private pure {
        if (_addressA == _addressB) {
            revert SCEngine__IdenticalTokenAndPriceFeed();
        }
    }
}
