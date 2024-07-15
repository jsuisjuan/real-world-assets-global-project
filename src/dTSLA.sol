// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

import { ConfirmedOwner } from '@chainlink/contracts/v0.8/ConfirmedOwner.sol';
import { FunctionsClient } from '@chainlink/contracts/v0.8/functions/dev/v1_0_0/FunctionsClient.sol';
import { FunctionsRequest } from '@chainlink/contracts/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol';
import { AggregatorV3Interface } from '@chainlink/contracts/v0.8/interfaces/AggregatorV3Interface.sol';

import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';

contract dTSLA is ConfirmedOwner, FunctionsClient, ERC20 {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;

    error dTSLA__NotEnoughtCollateral();
    error dTSLA__DoesntMeetMinimumWithdrawlAmount();
    error dTSLA__TransferFailed();

    enum MintOrRedeem {
        mint, redeem
    }

    struct dTslaRequest {
        uint256 amountOfToken;
        address requester;
        MintOrRedeem mintOrRedeem;
    }

    uint256 constant PRECISION = 1e18;
    address constant SEPOLIA_FUNCTIONS_ROUTER = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    address constant SEPOLIA_TSLA_PRICE_FEED = 0xc59E3633BAAC79493d908e63626716e204A45EdF;
    address constant SEPOLIA_USDC_PRICE_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
    address constant SEPOLIA_USDC = 0xAF0d217854155ea67D583E4CB5724f7caeC3Dc87;
    bytes32 constant DON_ID = hex'66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000';
    uint256 constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint32  constant GAS_LIMIT = 300_000;
    uint256 constant COLLATERAL_RATIO = 200;
    uint256 constant COLLATERAL_PRECISION = 100;
    uint256 constant MINIMUM_WITHDRAWL_AMOUNT = 100e18;

    uint64  immutable i_subId;
    string  private s_mintSourceCode;
    string  private s_redeemSourceCode;
    uint256 private s_portfolioBalance;
    bytes32 private s_mostRecentRequestId;

    mapping(bytes32 requestId => dTslaRequest request) private s_requestIdToRequest;
    mapping(address user => uint256 pendingWithdrawlAmount) private s_userToWithdrawlAmount;

    uint8 donHostedSecretsSlotID = 0;
    uint64 donHostedSecretsVersion = 1721067443;

    constructor(
        string memory mintSourceCode, 
        string memory redeemSourceCode,
        uint64 subId
    ) 
        ConfirmedOwner(msg.sender) 
        FunctionsClient(SEPOLIA_FUNCTIONS_ROUTER)
        ERC20('dTSLA', 'dTSLA') 
    {
        s_mintSourceCode = mintSourceCode;
        s_redeemSourceCode = redeemSourceCode;
        i_subId = subId;
    }

    function sendMintRequest(uint256 amount) external onlyOwner returns (bytes32) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_mintSourceCode);
        req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);
        bytes32 requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, DON_ID);
        s_mostRecentRequestId = requestId;
        s_requestIdToRequest[requestId] = dTslaRequest(amount, msg.sender, MintOrRedeem.mint);
        return requestId;
    }

    function _mintFulFillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 amountOfTokensToMint = s_requestIdToRequest[requestId].amountOfToken;
        s_portfolioBalance = uint256(bytes32(response));
        if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
            revert dTSLA__NotEnoughtCollateral();
        }
        if (amountOfTokensToMint != 0) {
            _mint(s_requestIdToRequest[requestId].requester, amountOfTokensToMint);
        }
    }

    function sendRedeemRequest(uint256 amountdTsla) external {
        uint256 amountTslaInUsdc = getUsdcValueOfUsd(getUsdcValueOfTsla(amountdTsla));
        if (amountTslaInUsdc < MINIMUM_WITHDRAWL_AMOUNT) {
            revert dTSLA__DoesntMeetMinimumWithdrawlAmount();
        }
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(s_redeemSourceCode);

        string[] memory args = new string[](2);
        args[0] = amountdTsla.toString();
        args[1] = amountTslaInUsdc.toString();
        req.setArgs(args);

        bytes32 requestId = _sendRequest(req.encodeCBOR(), i_subId, GAS_LIMIT, DON_ID);
        s_requestIdToRequest[requestId] = dTslaRequest(amountdTsla, msg.sender, MintOrRedeem.redeem);
        s_mostRecentRequestId = requestId;
        _burn(msg.sender, amountdTsla);
    }

    function _redeemFulFillRequest(bytes32 requestId, bytes memory response) internal {
        uint256 usdcAmount = uint256(bytes32(response));
        if (usdcAmount == 0) {
            uint256 amountOfdTSLABurned = s_requestIdToRequest[requestId].amountOfToken;
            _mint(s_requestIdToRequest[requestId].requester, amountOfdTSLABurned);
            return;
        }
        s_userToWithdrawlAmount[s_requestIdToRequest[requestId].requester] += usdcAmount;
    }

    function withdraw() external {
        uint256 amountToWithdraw = s_userToWithdrawlAmount[msg.sender];
        s_userToWithdrawlAmount[msg.sender] = 0;
        bool succ = ERC20(0xAF0d217854155ea67D583E4CB5724f7caeC3Dc87).transfer(msg.sender, amountToWithdraw);
        if (!succ) {
            revert dTSLA__TransferFailed();
        }
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory /*err*/) internal override {
        s_portfolioBalance = uint256(bytes32(response));
    }

    function finishMint() external onlyOwner {
        uint256 amountOfTokensToMint = s_requestIdToRequest[s_mostRecentRequestId].amountOfToken;
        if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
            revert dTSLA__NotEnoughtCollateral();
        }
        _mint(s_requestIdToRequest[s_mostRecentRequestId].requester, amountOfTokensToMint);
    }

    function _getCollateralRatioAdjustedTotalBalance(uint256 amountOfTokensToMint) internal view returns (uint256) {
        uint256 calculatedNewTotalValue = getCalculatedNewTotalValue(amountOfTokensToMint);
        return (calculatedNewTotalValue * COLLATERAL_RATIO) / COLLATERAL_PRECISION;
    }

    function getCalculatedNewTotalValue(uint256 addedNumberOfTokens) internal view returns (uint256) {
        return ((totalSupply() + addedNumberOfTokens) * getTslaPrice()) / PRECISION;
    }

    function getUsdcValueOfUsd(uint256 usdAmount) public view returns (uint256) {
        return (usdAmount * getUsdcPrice()) / PRECISION;
    }

    function getUsdcValueOfTsla(uint256 usdAmount) public view returns (uint256) {
        return (usdAmount * getTslaPrice()) / PRECISION;
    }

    function getTslaPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(SEPOLIA_TSLA_PRICE_FEED);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getUsdcPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(SEPOLIA_USDC_PRICE_FEED);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return uint256(price) * ADDITIONAL_FEED_PRECISION;
    }

    function getRequest(bytes32 requestId) public view returns (dTslaRequest memory) {
        return s_requestIdToRequest[requestId];
    }

    function getPendingWithdrawlAmount(address user) public view returns (uint256) {
        return s_userToWithdrawlAmount[user];
    }

    function getPortfolioBalance() public view returns (uint256) {
        return i_subId;
    }

    function getMintSourceCode() public view returns (string memory) {
        return s_mintSourceCode;
    }

    function getRedeemSourceCode() public view returns (string memory) {
        return s_redeemSourceCode;
    }

    function getCollateralRatio() public pure returns (uint256) {
        return COLLATERAL_RATIO;
    }

    function getCollateralPrecision() public pure returns (uint256) {
        return COLLATERAL_PRECISION;
    }
}