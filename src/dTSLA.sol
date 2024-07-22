// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { ConfirmedOwner } from '@chainlink/contracts/v0.8/ConfirmedOwner.sol';
import { FunctionsClient } from '@chainlink/contracts/v0.8/functions/dev/v1_0_0/FunctionsClient.sol';
import { FunctionsRequest } from '@chainlink/contracts/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol';
import { OracleLib, AggregatorV3Interface } from "./libraries/OracleLib.sol";
import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';
import { Pausable } from '@openzeppelin/contracts/utils/Pausable.sol';

/**
 * @title dTSLA
 * @notice This is our contract to make requests to the Alpaca API to mint TSLA-backed dTSLA tokens
 * @dev This contract is meant to be for educational purposes only
 */
contract dTSLA is ConfirmedOwner, FunctionsClient, ERC20, Pausable {
    using FunctionsRequest for FunctionsRequest.Request;
    using OracleLib for AggregatorV3Interface;
    using Strings for uint256;

    error dTSLA__NotEnoughtCollateral();
    error dTSLA__BelowMinimumRedemption();
    error dTSLA__RedemptionFailed();

    enum MintOrRedeem {
        mint, 
        redeem
    }

    struct dTslaRequest {
        uint256 amountOfToken;
        address requester;
        MintOrRedeem mintOrRedeem;
    }

    uint256 constant PRECISION = 1e18;
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint32 constant GAS_LIMIT = 300_000;
    uint256 constant COLLATERAL_RATIO = 200; // 200% collateral ration means if there is $200 of TSLA in the brokerage, we can mint AT MOST %100 of dTSLA
    uint256 constant COLLATERAL_PRECISION = 100;
    uint256 constant MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT = 100e18; // USDC has 6 decimals

    address s_functionsRouter;
    string s_mintSource;
    string s_redeemSource;
    bytes32 s_donID;
    uint256 s_portfolioBalance;
    bytes32 s_mostRecentRequestId;
    uint64 s_secretVersion;
    uint8 s_secretSlot;

    mapping(bytes32 requestId => dTslaRequest request) private s_requestIdToRequest;
    mapping(address user => uint256 pendingWithdrawlAmount) private s_userToWithdrawlAmount;

    uint64 immutable i_subId;
    address public i_tslaUsdFeed;
    address public i_usdcUsdFeed;
    address public i_redemptionCoin;
    uint256 private immutable i_redemptionCoinDecimals;

    event Response(bytes32 indexed requestId, uint256 character, bytes response, bytes err);

    constructor(uint64 subId, string memory mintSource, string memory redeemSource, address functionsRouter, bytes32 donId, address tslaPriceFeed, address usdcPriceFeed, address redemptionCoin, uint64 secretVersion, uint8 secretSlot) FunctionsClient(functionsRouter) ConfirmedOwner(msg.sender) ERC20("Backed TSLA", "bTSLA") {
        (s_mintSource, s_redeemSource, s_functionsRouter, s_donID, s_secretVersion, s_secretSlot) = (mintSource, redeemSource, functionsRouter, donId, secretVersion, secretSlot);
        (i_tslaUsdFeed, i_usdcUsdFeed, i_subId, i_redemptionCoin) = (tslaPriceFeed, usdcPriceFeed, subId, redemptionCoin);
        i_redemptionCoinDecimals = ERC20(redemptionCoin).decimals();
    }

    /**
    * @dev Sets the version of the secret.
    * @param secretVersion The new version of the secret.
    */
    function setSecretVersion(uint64 secretVersion) external onlyOwner {
        s_secretVersion = secretVersion;
    }

    /**
    * @dev Sets the slot of the secret.
    * @param secretSlot The new slot of the secret.
    */
    function setSecretSlot(uint8 secretSlot) external onlyOwner {
        s_secretSlot = secretSlot;
    }

    /**
    * @dev Sends a mint request.
    * @param amountOfTokensToMint The amount of tokens to mint.
    * @return requestId The ID of the request.
    */
    function sendMintRequest(uint256 amountOfTokensToMint) external onlyOwner whenNotPaused returns (bytes32 requestId) {
        checkPortfolioBalance(amountOfTokensToMint);
        FunctionsRequest.Request memory req = createMintFunctionsRequest();
        return sendRequestAndStoreId(req, amountOfTokensToMint, MintOrRedeem.mint);
    }

    /**
    * @dev Checks the portfolio balance.
    * @param amountOfTokensToMint The amount of tokens to mint.
    */
    function checkPortfolioBalance(uint256 amountOfTokensToMint) private view {
        if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
            revert dTSLA__NotEnoughtCollateral();
        }
    }

    /**
    * @dev Creates a functions request for minting.
    * @return req The created request.
    */
    function createMintFunctionsRequest() private view returns (FunctionsRequest.Request memory req) {
        req.initializeRequestForInlineJavaScript(s_mintSource);
        req.addDONHostedSecrets(s_secretSlot, s_secretVersion);
        return req;
    }

    /**
    * @dev Sends a redeem request.
    * @param amountdTsla The amount of dTSLA to redeem.
    * @return requestId The ID of the request.
    */
    function sendRedeemRequest(uint256 amountdTsla) external whenNotPaused returns (bytes32 requestId) {
        uint256 amountTslaInUsdc = getUsdcValueOfUsd(getUsdValueOfTsla(amountdTsla));
        checkMinimumRedemptionCoinRedemptionAmount(amountTslaInUsdc);
        FunctionsRequest.Request memory req = createRedeemFunctionsRequest(amountdTsla, amountTslaInUsdc);
        requestId = sendRequestAndStoreId(req, amountdTsla, MintOrRedeem.redeem);
        _burn(msg.sender, amountdTsla);
    }

    /**
    * @dev Checks if the minimum redemption coin amount is met.
    * @param amountTslaInUsdc The amount of TSLA in USDC.
    */
    function checkMinimumRedemptionCoinRedemptionAmount(uint256 amountTslaInUsdc) private pure {
        if (amountTslaInUsdc < MINIMUM_REDEMPTION_COIN_REDEMPTION_AMOUNT) {
            revert dTSLA__BelowMinimumRedemption();
        }
    }

    /**
    * @dev Creates a functions request for redeeming.
    * @param amountdTsla The amount of dTSLA to redeem.
    * @param amountTslaInUsdc The amount of TSLA in USDC.
    * @return req The created request.
    */
    function createRedeemFunctionsRequest(uint256 amountdTsla, uint256 amountTslaInUsdc) private view returns (FunctionsRequest.Request memory req) {
        req.initializeRequestForInlineJavaScript(s_redeemSource);
        string[] memory args = new string[](2);
        args[0] = amountdTsla.toString();
        args[1] = amountTslaInUsdc.toString();
        req.setArgs(args);
        return req;
    }

    /**
    * @dev Sends the request and stores the request ID.
    * @param req The functions request.
    * @param amountOfTokens The amount of tokens.
    * @param mintOrRedeem Enum indicating whether it's a mint or redeem request.
    * @return requestId The ID of the request.
    */
    function sendRequestAndStoreId(FunctionsRequest.Request memory req, uint256 amountOfTokens, MintOrRedeem mintOrRedeem) private returns (bytes32 requestId) {
        requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, s_donID);
        s_requestIdToRequest[requestId] = dTslaRequest(amountOfTokens, msg.sender, mintOrRedeem);
    }

    /**
    * @dev Fulfills a mint or redeem request.
    * @param requestId The ID of the request.
    * @param response The response of the request.
    */
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory /*err*/) internal override whenNotPaused {
        s_requestIdToRequest[requestId].mintOrRedeem == MintOrRedeem.mint ? _mintFulFillRequest(requestId, response) : _redeemFulFillRequest(requestId, response);
    }

    /**
    * @dev Withdraws the user's balance.
    */
    function withdraw() external whenNotPaused {
        uint256 amountToWithdraw = s_userToWithdrawlAmount[msg.sender];
        s_userToWithdrawlAmount[msg.sender] = 0;
        sendUserUsdc(amountToWithdraw);
    }

    /**
    * @dev Sends USDC to the user.
    * @param amountToWithdraw The amount of USDC to withdraw.
    */
    function sendUserUsdc(uint256 amountToWithdraw) private {
        bool succ = ERC20(i_redemptionCoin).transfer(msg.sender, amountToWithdraw);
        if (!succ) revert dTSLA__RedemptionFailed();
    }

    /**
    * @dev Pauses the contract.
    */
    function pause() external onlyOwner {
        _pause();
    }

    /**
    * @dev Unpauses the contract.
    */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
    * @dev Fulfills a mint request.
    * @param requestId The ID of the request.
    * @param response The response of the request.
    */
    function _mintFulFillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 amountOfTokensToMint = s_requestIdToRequest[requestId].amountOfToken;
        s_portfolioBalance = uint256(bytes32(response));
        checkPortfolioBalance(amountOfTokensToMint);
        if (amountOfTokensToMint != 0) _mint(s_requestIdToRequest[requestId].requester, amountOfTokensToMint);
    }

    /**
    * @dev Fulfills a redeem request.
    * @param requestId The ID of the request.
    * @param response The response of the request.
    */
    function _redeemFulFillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 usdcAmount = uint256(bytes32(response));
        uint256 usdcAmountWad = adjustUsdcAmount(usdcAmount);
        isZeroUsdcAmount(usdcAmount) ? handleZeroUsdcAmount(requestId) : handleNonZeroUsdcAmount(requestId, usdcAmountWad);
    }

    /**
    * @dev Adjusts the USDC amount to the Wad format if the redemption coin decimals are less than 18.
    * @param usdcAmount The amount of USDC.
    * @return usdcAmountWad The adjusted amount of USDC.
    */
    function adjustUsdcAmount(uint256 usdcAmount) private view returns (uint256 usdcAmountWad) {
        return (i_redemptionCoinDecimals < 18) ? usdcAmount * (10 ** (18 - i_redemptionCoinDecimals)) : usdcAmount;
    }

    /**
    * @dev Checks if the USDC amount is zero.
    * @param usdcAmount The amount of USDC.
    * @return bool True if the amount is zero, false otherwise.
    */
    function isZeroUsdcAmount(uint256 usdcAmount) private pure returns (bool) {
        return usdcAmount == 0;
    }

    /**
    * @dev Handles the case where the USDC amount is zero.
    * @param requestId The ID of the request.
    */
    function handleZeroUsdcAmount(bytes32 requestId) private {
        uint256 amountOfdTSLABurned = s_requestIdToRequest[requestId].amountOfToken;
        _mint(s_requestIdToRequest[requestId].requester, amountOfdTSLABurned);
    }

    /**
    * @dev Handles the case where the USDC amount is non-zero.
    * @param requestId The ID of the request.
    * @param usdcAmount The amount of USDC.
    */
    function handleNonZeroUsdcAmount(bytes32 requestId, uint256 usdcAmount) private {
        s_userToWithdrawlAmount[s_requestIdToRequest[requestId].requester] += usdcAmount;
    }

    /**
    * @dev Gets the total balance adjusted by the collateral ratio.
    * @param amountOfTokensToMint The amount of tokens to mint.
    * @return The adjusted total balance.
    */
    function _getCollateralRatioAdjustedTotalBalance(uint256 amountOfTokensToMint) internal view returns (uint256) {
        uint256 calculatedNewTotalValue = getCalculatedNewTotalValue(amountOfTokensToMint);
        return (calculatedNewTotalValue * COLLATERAL_RATIO) / COLLATERAL_PRECISION;
    }

    /**
    * @dev Gets the portfolio balance.
    * @return The portfolio balance.
    */
    function getPortfolioBalance() public view returns (uint256) {
        return s_portfolioBalance;
    }

    /**
    * @dev Gets the TSLA price.
    * @return The TSLA price.
    */
    function getTslaPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_tslaUsdFeed);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    /**
    * @dev Gets the USDC price.
    * @return The USDC price.
    */
    function getUsdcPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(i_usdcUsdFeed);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    /**
    * @dev Gets the USD value of TSLA.
    * @param tslaAmount The amount of TSLA.
    * @return The USD value of TSLA.
    */
    function getUsdValueOfTsla(uint256 tslaAmount) public view returns (uint256) {
        return (tslaAmount * getTslaPrice()) / PRECISION;
    }

    /**
    * @dev Gets the USDC value of USD.
    * @param usdAmount The amount of USD.
    * @return The USDC value of USD.
    */
    function getUsdcValueOfUsd(uint256 usdAmount) public view returns (uint256) {
        return (usdAmount * PRECISION) / getUsdcPrice(); // talvez isso esteja errado
    }

    /**
    * @dev Gets the calculated new total value.
    * @param addedNumberOfTsla The amount of TSLA added.
    * @return The calculated new total value.
    */
    function getCalculatedNewTotalValue(uint256 addedNumberOfTsla) internal view returns (uint256) {
        return ((totalSupply() + addedNumberOfTsla) * getTslaPrice()) / PRECISION;
    }

    /**
    * @dev Gets a request by ID.
    * @param requestId The ID of the request.
    * @return The dTsla request.
    */
    function getRequest(bytes32 requestId) public view returns (dTslaRequest memory) {
        return s_requestIdToRequest[requestId];
    }

    /**
    * @dev Gets the withdrawal amount for a user.
    * @param user The address of the user.
    * @return The withdrawal amount of the user.
    */
    function getWithdrawlAmount(address user) public view returns (uint256) {
        return s_userToWithdrawlAmount[user];
    } 
}