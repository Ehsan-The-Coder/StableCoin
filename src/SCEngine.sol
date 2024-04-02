// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//<----------------------------import statements---------------------------->
import {Utilis} from "./Libraries/Utilis.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StableCoin} from "./StableCoin.sol";
import {ChainlinkManager} from "./libraries/ChainlinkManager.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {console} from "forge-std/Script.sol";

/**
 * @title StableCoin (SC)Engine
 * @author Muhammad Ehsan orginal patrick alphac
 *
 * The Stablecoin (SC) system is a fintech innovation that combines technology and finance to create a stablecoin with unique features, setting it apart from other cryptocurrencies.
 * It's Exogenously Collateralized, using external assets as collateral to ensure its value is stable and tied to real-world collateral values.
 * Dollar Pegged, it maintains a 1:1 value with the US dollar, offering a stable and predictable currency.
 * Algorithmically Stable, it uses sophisticated algorithms to manage supply and demand, ensuring stability in volatile markets.
 * It's like MakerDAO but more simpler.
 *
 * Requires "overcollateralization" to ensure the value of all collateral is always greater than the dollar-backed value of all minted SC, maintaining system security and stability.
 *
 * The `SCEngine` contract manages minting, redeeming, and collateral operations, designed to be minimalistic and focus on essential functionalities for SC stability and security.
 * The `StableCoin` contract creates and manages SC tokens, ensuring minting and burning as needed to maintain supply and demand.
 * Together, `SCEngine` and `StableCoin` form the core of the Decentralized Stablecoin system, providing a secure, stable cryptocurrency backed by real-world assets and pegged to the US dollar.
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 */
contract SCEngine is ReentrancyGuard {
    //<----------------------------state variable---------------------------->
    // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    // This means you get assets at a 10% discount when liquidating
    uint256 private constant LIQUIDATION_BONUS = 10;

    ///@dev mapping of token to chainlink pricefeed address
    mapping(address token => address priceFeed) private s_tokenPriceFeed;
    address[] private s_tokens;
    ///@dev  mapping from user(depositor) to asset token collateral address to balance
    mapping(address depositer => mapping(address tokenCollateralAddress => uint balance))
        private s_collateralDeposited;
    ///@dev mapping from user token sc minted to balance
    mapping(address minter => uint256 balance) private s_scMinted;
    address private immutable i_stableCoin;

    //<----------------------------events---------------------------->
    /**
     * @notice Emitted when collateral is deposited into the system.
     * @param depositer The address of the depositor.
     * @param tokenCollateralAddress The address of the collateral token.
     * @param quantity The amount of collateral deposited.
     */
    event CollataralDeposited(
        address indexed depositer,
        address indexed tokenCollateralAddress,
        uint256 quantity
    );

    /**
     * @notice Emitted when collateral is redeemed from the system.
     * @param from The address from which the collateral is redeemed.
     * @param to The address to which the collateral is redeemed.
     * @param tokenCollateralAddress The address of the collateral token.
     * @param amountCollateral The amount of collateral redeemed.
     */
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
    /**
     * @notice Ensures that two input arrays have same lengths.
     * @dev This modifier is used to validate constructor parameters to ensure they are of same lengths.
     * @param lengthA The length of the first array.
     * @param lengthB The length of the second array.
     */
    modifier notEqualLength(uint256 lengthA, uint256 lengthB) {
        if (lengthA != lengthB) {
            revert SCEngine__LengthOfConstructorValuesNotEqual(
                lengthA,
                lengthB
            );
        }
        _;
    }

    /**
     * @notice Checks if a token is listed in the system.
     * @dev This modifier is used to ensure that operations involving tokens are only performed with tokens that are recognized by the system.
     * @param token The address of the token to check.
     */
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
    /**
     * @dev Initializes the SCEngine contract with a list of tokens and their corresponding Chainlink price feeds, as well as the address of the StableCoin contract.
     * @param token An array of addresses representing the tokens to be supported by the SCEngine.
     * @param priceFeed An array of addresses representing the Chainlink price feeds for the corresponding tokens.
     * @param stableCoin The address of the StableCoin contract that will be used for minting and burning SC tokens.
     *
     * Requirements:
     * - The lengths of the `token` and `priceFeed` arrays must be equal.
     * - The `token` and `priceFeed` arrays must not be empty.
     * - The `stableCoin` address must not be the zero address.
     * - No token address in the `token` array can be the same as any price feed address in the `priceFeed` array.
     */
    constructor(
        address[] memory token,
        address[] memory priceFeed,
        address stableCoin
    )
        notEqualLength(token.length, priceFeed.length)
        isValueZero(token.length)
        isValueZero(priceFeed.length)
    {
        address _token;
        address _priceFeed;
        for (uint256 index = 0; index < token.length; index++) {
            _token = token[index];
            _priceFeed = priceFeed[index];

            if (_token == address(0) || _priceFeed == address(0)) {
                revert SCEngine__ZeroAddress();
            }
            if (_token == _priceFeed) {
                revert SCEngine__IdenticalTokenAndPriceFeed();
            }

            s_tokenPriceFeed[_token] = _priceFeed;
            s_tokens.push(_token);
        }
        if (stableCoin == address(0)) {
            revert SCEngine__ZeroAddress();
        }
        i_stableCoin = stableCoin;
    }

    //<----------------------------external functions---------------------------->
    /**
     * @dev Allows a user to deposit collateral and mint StableCoin (SC) in a single transaction.
     * @param tokenCollateralAddress The address of the collateral token to be deposited.
     * @param quantity The amount of collateral to be deposited.
     * @param mintQuantity The amount of StableCoin (SC) to be minted.
     *
     * Requirements:
     * - The `tokenCollateralAddress` must be a token that is supported by the SCEngine.
     * - The `quantity` must be greater than 0.
     * - The `mintQuantity` must be greater than 0.
     *
     * @notice This function updates the user's collateral balance and the total SC minted.
     * @notice It emits a `CollataralDeposited` event upon successful deposit and a `TokenMinted` event upon successful minting.
     * @notice The actual minting of SC tokens is handled by the `mintSc` function, which is called within this function.
     */
    function depositCollataralAndMintSc(
        address tokenCollateralAddress,
        uint256 quantity,
        uint256 mintQuantity
    ) external {
        depositCollataral(tokenCollateralAddress, quantity);
        mintSc(mintQuantity);
    }

    /**
     * @dev Allows a user to redeem collateral for StableCoin (SC) in a single transaction.
     * @param token The address of the collateral token to be redeemed.
     * @param quantityOfCollateral The amount of collateral to be redeemed.
     * @param quantityToBurn The amount of StableCoin (SC) to be burned.
     *
     * Requirements:
     * - The `token` must be a token that is supported by the SCEngine.
     * - The `quantityOfCollateral` must be greater than 0.
     * - The `quantityToBurn` must be greater than 0.
     *
     * @notice This function updates the user's collateral balance and the total SC burned.
     * @notice It emits a `CollateralRedeemed` event upon successful redemption.
     * @notice The actual burning of SC tokens is handled by the `_burnSc` function, which is called within this function.
     */
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

    /**
     * @dev Allows a user to redeem collateral from the system.
     * @param token The address of the collateral token to be redeemed.
     * @param quantity The amount of collateral to be redeemed.
     *
     * Requirements:
     * - The `token` must be a token that is supported by the SCEngine.
     * - The `quantity` must be greater than 0.
     *
     * @notice This function updates the user's collateral balance.
     * @notice It emits a `CollateralRedeemed` event upon successful redemption.
     * @notice The actual redemption of collateral is handled by the `_redeemCollateral` function, which is called within this function.
     */
    function redeemCollateral(
        address token,
        uint256 quantity
    ) external isValueZero(quantity) nonReentrant isTokenExisted(token) {
        _redeemCollateral(token, quantity, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @dev Allows a user to burn StableCoin (SC) tokens.
     * @param quantity The amount of StableCoin (SC) to be burned.
     *
     * Requirements:
     * - The `quantity` must be greater than 0.
     *
     * @notice This function updates the user's SC balance.
     * @notice The actual burning of SC tokens is handled by the `_burnSc` function, which is called within this function.
     */
    function burnSc(uint256 quantity) external isValueZero(quantity) {
        _burnSc(quantity, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // I don't think this would ever hit...
    }

    /**
     * @dev Allows a user to liquidate collateral to cover debt, with a 10% bonus for the liquidator.
     * @param token The address of the collateral token to be liquidated.
     * @param user The address of the user whose collateral is being liquidated.
     * @param debtToCover The amount of SC you want to burn to cover the user's debt.
     *
     * @notice You can partially liquidate a user.
     * @notice You will get a 10% LIQUIDATION_BONUS for taking the users funds.
     * @notice This function working assumes that the protocol will be roughly 150% overcollateralized in order for this to work.
     * @notice A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate anyone.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     *
     * Requirements:
     * - The `token` must be a token that is supported by the SCEngine.
     * - The `debtToCover` must be greater than 0.
     * - The user's health factor must be below the minimum health factor threshold.
     * - The liquidator health factor must not be also broken.
     *
     * @notice This function updates the user's collateral balance and the total SC burned.
     * @notice It emits a `CollateralRedeemed` event upon successful redemption.
     * @notice The actual liquidation process involves redeeming collateral and burning SC tokens to cover the debt.
     */
    function liquidate(
        address token,
        address user,
        uint256 debtToCover
    ) external isValueZero(debtToCover) nonReentrant {
        uint256 startingUserHealthFactor = _healthFactor(user);
        // revert if the health factor is broken
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert SCEngine__HealthFactorOk();
        }
        // Calculates the amount of collateral token needed to cover the specified debt amount in USD.
        // This is done by converting the debt amount from USD to the equivalent amount in the collateral token.
        // The conversion rate is obtained from the Chainlink price feed associated with the collateral token.
        // The result is stored in the variable `tokenAmountFromDebtCovered`, which represents the amount of collateral token required to cover the debt.
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(
            token,
            debtToCover
        );
        // Calculates the bonus collateral amount for the liquidator based on the debt covered.
        // The bonus is a percentage of the collateral token amount needed to cover the debt, adjusted by `LIQUIDATION_PRECISION`.
        // The result is stored in `bonusCollateral`, representing the additional bonus received by the liquidator.
        uint256 bonusCollateral = (tokenAmountFromDebtCovered *
            LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        _redeemCollateral(
            token,
            tokenAmountFromDebtCovered + bonusCollateral,
            user,
            msg.sender
        );
        startingUserHealthFactor = _healthFactor(user);
        _burnSc(debtToCover, user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert SCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    //<----------------------------public functions---------------------------->
    /**
     * @dev Allows a user to deposit collateral into the system.
     * @param tokenCollateralAddress The address of the collateral token to be deposited.
     * @param quantity The amount of collateral to be deposited.
     *
     * @notice This function updates the user's collateral balance.
     * @notice It emits a `CollataralDeposited` event upon successful deposit.
     * @notice The actual deposit of collateral is handled by transferring the specified amount of tokens from the user to the contract.
     *
     * Requirements:
     * - The `tokenCollateralAddress` must be a token that is supported by the SCEngine.
     * - The `quantity` must be greater than 0.
     * - The user must have enough balance of the specified token to cover the deposit.
     */
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

    /**
     * @dev Allows a user to mint StableCoin (SC) tokens.
     * @param quantity The amount of StableCoin (SC) to be minted.
     *
     * @notice This function updates the user's SC balance.
     * @notice The actual minting of SC tokens is handled by the `StableCoin` contract's `mint` function.
     *
     * Requirements:
     * - The `quantity` must be greater than 0.
     * - The user must have enough collateral deposited to cover the minting operation.
     */
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
    /**
     * @dev Converts a given amount in USD to the equivalent amount in a specified collateral token.
     * @param token The address of the collateral token for which the conversion is needed.
     * @param usdAmountInWei The amount in USD to be converted, represented in Wei (the smallest unit of Ether).
     *
     * @notice This function uses the Chainlink price feed associated with the specified token to perform the conversion.
     * @notice It assumes that the price feed returns a valid price for the token.
     *
     * @return Returns the equivalent amount in the specified collateral token for the given USD amount.
     */
    function getTokenAmountFromUsd(
        address token,
        uint256 usdAmountInWei
    ) public view isTokenExisted(token) returns (uint256) {
        //getting the price from chainlink pricefeed
        uint256 price = ChainlinkManager.getPrice(s_tokenPriceFeed[token]);
        if (price == 0) {
            return 0;
        }
        return (((usdAmountInWei * PRECISION) / price)) / PRECISION;
    }

    // Gets the health factor of a user.
    function getUserHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    // Calculates the health factor of a user.
    function calculateUserHealthFactor(
        uint256 totalScMinted,
        uint256 collateralValueInUsd
    ) external pure returns (uint256) {
        return _calculateHealthFactor(totalScMinted, collateralValueInUsd);
    }

    // Retrieves account information.
    function getAccountInformation(
        address user
    )
        external
        view
        returns (uint256 totalScMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    // Returns the StableCoin contract address.
    function getStableCoin() external view returns (address) {
        return i_stableCoin;
    }

    // Lists supported collateral tokens.
    function getTokens() external view returns (address[] memory) {
        return s_tokens;
    }

    // Gets the price feed address for a token.
    function getPriceFeed(
        address token
    ) external view returns (address priceFeed) {
        return s_tokenPriceFeed[token];
    }

    // Fetches the current price of a pricefeed address.
    function getPrice(address priceFeed) external view returns (uint256) {
        return ChainlinkManager.getPrice(priceFeed);
    }

    // Calculates the total amount of a token in USD.
    function getTotalAmount(
        address priceFeed,
        uint256 quantity
    ) external view returns (uint256) {
        return ChainlinkManager.getTotalAmount(priceFeed, quantity);
    }

    // Returns the liquidation threshold.
    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    // Returns the minimum health factor.
    function getMinimumHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    // Returns the precision for calculations.
    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    // Returns the liquidation precision.
    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    // Gets the collateral balance of a depositor.
    function getDepositerCollateralBalance(
        address depositer,
        address tokenCollateralAddress
    ) external view returns (uint256) {
        return s_collateralDeposited[depositer][tokenCollateralAddress];
    }

    // Gets the total SC minted by a minter.
    function getMinterMintBalance(
        address minter
    ) external view returns (uint256) {
        return s_scMinted[minter];
    }

    //<----------------------------private functions---------------------------->
    /**
     * @dev Private function to redeem collateral from the system.
     * @param tokenCollateralAddress The address of the collateral token to be redeemed.
     * @param quantity The amount of collateral to be redeemed.
     * @param from The address from which the collateral is redeemed.
     * @param to The address to which the collateral is redeemed.
     *
     * @notice This function updates the user's collateral balance.
     * @notice It emits a `CollateralRedeemed` event upon successful redemption.
     * @notice The actual redemption of collateral is handled by transferring the specified amount of tokens from the contract to the user.
     */
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

    /**
     * @dev Private function to burn StableCoin (SC) tokens.
     * @param quantity The amount of StableCoin (SC) to be burned.
     * @param onBehalfOf The address of the user on whose behalf the SC tokens are being burned.
     * @param scFrom The address from which the SC tokens are being burned.
     *
     * @notice This function updates the user's SC balance and the total SC burned.
     * @notice The actual burning of SC tokens is handled by transferring the specified amount of tokens from the user to the contract and then burning them.
     */
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

    /**
     * @dev Private function to calculate the health factor of a user.
     * @param user The address of the user for whom the health factor is being calculated.
     *
     * @notice The health factor is a measure of the user's collateralization level, indicating how much collateral they have deposited relative to the amount of StableCoin (SC) they have minted.
     * @notice A higher health factor indicates a more secure position, with the minimum health factor threshold representing a safe level of collateralization.
     *
     *Returns the health factor of the user, which is a ratio of the user's collateral value in USD to the value of the SC tokens they have minted.
     */
    function _healthFactor(address user) private view returns (uint256) {
        (
            uint256 totalScMinted,
            uint256 collateralValueInUsd
        ) = _getAccountInformation(user);
        return _calculateHealthFactor(totalScMinted, collateralValueInUsd);
    }

    /**
     * @dev Private function to retrieve account information, including the total amount of StableCoin (SC) minted and the total value of the user's collateral in USD.
     * @param user The address of the user for whom the account information is being retrieved.
     *
     * @notice This function calculates the total SC minted by the user and the total value of their collateral in USD.
     * @notice It iterates over all supported collateral tokens to sum up the collateral value.
     *
     * @return totalScMinted The total amount of SC minted by the user.
     * @return collateralValueInUsd The total value of the user's collateral in USD.
     */
    function _getAccountInformation(
        address user
    ) private view returns (uint256, uint256) {
        uint256 collateralValueInUsd;
        uint256 totalScMinted;
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

    /**
     * @dev Private function to calculate the health factor based on the total amount of StableCoin (SC) minted and the collateral value in USD.
     * @param totalScMinted The total amount of StableCoin (SC) minted by the user.
     * @param collateralValueInUsd The total value of the user's collateral in USD.
     *
     * @notice The health factor is a measure of the user's collateralization level, indicating how much collateral they have deposited relative to the amount of SC they have minted.
     * @notice A higher health factor indicates a more secure position, with the minimum health factor threshold representing a safe level of collateralization.
     *
     * @return Returns the calculated health factor, which is a ratio of the user's collateral value in USD to the value of the SC tokens they have minted.
     */
    function _calculateHealthFactor(
        uint256 totalScMinted,
        uint256 collateralValueInUsd
    ) private pure returns (uint256) {
        if (totalScMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalScMinted;
    }

    /**
     * @dev Private function to check if the user's health factor is below the minimum health factor threshold.
     * @param user The address of the user whose health factor is being checked.
     *
     * @notice This function reverts the transaction if the user's health factor is below the minimum health factor threshold.
     * @notice The health factor is a measure of the user's collateralization level, indicating how much collateral they have deposited relative to the amount of SC they have minted.
     * @notice A health factor below the minimum threshold indicates a potential risk to the system, and operations that could further increase this risk are not allowed.
     */
    function _revertIfHealthFactorIsBroken(address user) private view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert SCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }
}
