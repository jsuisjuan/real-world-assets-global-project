const { secrets } = require("../configs/alpacaMintConfig");

const ASSET_TICKER = 'TSLA';
const CRYPTO_TICKER = 'USDCUSD';
const RWA_CONTRACT = '0xd8b51ead97A4c5C47C01E02748d6930745267D06';
const SLEEP_TIME = 5000;

/**
* Main function that coordinates the trading process.
* 
* @returns {Promise<Uint256>} The amount of USDC encoded in Uint256 if successful, otherwise 0.
*/
async function main() {
    const amountTsla = args[0];
    const amountUsdc = args[1];
    _checkKeys();

    let orderFilled = await executeTrade(ASSET_TICKER, amountTsla, 'sell');
    if (!orderFilled) return Functions.encodeUint256(0);

    orderFilled = await executeTrade(CRYPTO_TICKER, amountTsla, 'buy');
    if (!orderFilled) return Functions.encodeUint256(0);

    const transferId = await sendUsdcToContract(amountUsdc);
    if (transferId === null) return Functions.encodeUint256(0);
    
    const transferCompleted = await waitForCryptoTransferToComplete(transferId);
    if (!transferCompleted) return Functions.encodeUint256(0);
    
    return Functions.encodeUint256(amountUsdc);
}

/**
* Executes a trade by placing an order and waiting for it to fill.
* 
* @param {string} ticker - The ticker symbol of the asset.
* @param {string} amount - The amount to trade.
* @param {string} side - The side of the trade ('buy' or 'sell').
* @returns {Promise<boolean>} True if the order was filled, otherwise false.
*/
async function executeTrade(ticker, amount, side) {
    const [client_order_id, orderStatus, responseStatus] = await placeOrder(ticker, amount, side);
    if (responseStatus !== 200 || orderStatus !== 'accepted') return false;
    const filled = await waitForOrderToFill(client_order_id);
    if (!filled) await cancelOrder(client_order_id);
    return filled;
}

/**
* Places an order on the Alpaca API.
* 
* @param {string} symbol - The ticker symbol of the asset.
* @param {string} qty - The quantity to trade.
* @param {string} side - The side of the trade ('buy' or 'sell').
* @returns {Promise<[string, string, number]>} The client order ID, order status, and response status.
*/
async function placeOrder(symbol, qty, side) {
    const alpacaSellRequest = Functions.makeHttpRequest({
        method: 'POST',
        url: 'https://paper-api.alpaca.markets/v2/orders',
        headers: {
            accept: 'application/json',
            'content-type': 'application/json',
            'APCA-API-KEY-ID': secrets.alpacaKey,
            'APCA-API-SECRET-KEY': secrets.alpacaSecret
        },
        data: { side, type: 'market', time_in_force: 'gtc', symbol, qty }
    });
    const response = await alpacaSellRequest;
    const responseStatus = response.status;
    const { client_order_id, status: orderStatus } = response.data;
    return client_order_id, orderStatus, responseStatus;
}

/**
* Cancels an order on the Alpaca API.
* 
* @param {string} client_order_id - The client order ID.
* @returns {Promise<number>} The response status.
*/
async function cancelOrder(client_order_id) {
    const alpacaCancelRequest = Functions.makeHttpRequest({
        method: 'DELETE',
        url: `https://paper-api.alpaca.markets/v2/orders/${client_order_id}`,
        headers: {
            accept: 'application/json',
            'APCA-API-KEY-ID': secrets.alpacaKey,
            'APCA-API-SECRET-KEY': secrets.alpacaSecret
        }
    });
    const response = await alpacaCancelRequest;
    return response.status;
}

/**
* Waits for an order to fill by repeatedly checking its status.
* 
* @param {string} client_order_id - The client order ID.
* @returns {Promise<boolean>} True if the order was filled, otherwise false.
*/
async function waitForOrderToFill(client_order_id) {
    const capNumberOfSleeps = 10;
    let numberOfSleeps = 0;
    while (numberOfSleeps < capNumberOfSleeps) {
        const orderStatus = await checkOrderStatus(client_order_id);
        if (orderStatus === 'filled') return true;
        numberOfSleeps++;
        await sleep(SLEEP_TIME);
    }
    return false;
}

/**
* Checks the status of an order on the Alpaca API.
* 
* @param {string} client_order_id - The client order ID.
* @returns {Promise<string>} The order status.
*/
async function checkOrderStatus(client_order_id) {
    const alpacaOrderStatusRequest = Functions.makeHttpRequest({
        method: 'GET',
        url: `https://paper-api.alpaca.markets/v2/orders/${client_order_id}`,
        headers: {
            accept: 'application/json',
            'APCA-API-KEY-ID': secrets.alpacaKey,
            'APCA-API-SECRET-KEY': secrets.alpacaSecret
        }
    });
    const response = await alpacaOrderStatusRequest;
    const { status: orderStatus } = response.data;
    return orderStatus;
}

/**
* Sends USDC to the specified contract.
* 
* @param {string} usdcAmount - The amount of USDC to send.
* @returns {Promise<string|null>} The transfer ID if successful, otherwise null.
*/
async function sendUsdcToContract(usdcAmount) {
    const transferRequest = Functions.makeHttpRequest({
        method: 'POST',
        url: 'https://paper-api.alpaca.markets/v2/wallets/transfers',
        headers: {
            accept: 'application/json',
            'content-type': 'application/json',
            'APCA-API-KEY-ID': secrets.alpacaKey,
            'APCA-API-SECRET-KEY': secrets.alpacaSecret
        },
        data: { amount: usdcAmount, address: RWA_CONTRACT, asset: CRYPTO_TICKER }
    });
    const response = await transferRequest;
    return response.status === 200 ? response.data.id : null;
}

/**
* Waits for a crypto transfer to complete by repeatedly checking its status.
* 
* @param {string} transferId - The transfer ID.
* @returns {Promise<boolean>} True if the transfer was completed, otherwise false.
*/
async function waitForCryptoTransferToComplete(transferId) {
    const capNumberOfSleeps = 120;
    let numberOfSleeps = 0;
    while (numberOfSleeps < capNumberOfSleeps) {
        const transferStatus = await checkTransferStatus(transferId);
        if (transferStatus === 'completed') return true;
        numberOfSleeps++;
        await sleep(SLEEP_TIME); 
    }
    return false;
}

/**
* Checks the status of a crypto transfer on the Alpaca API.
* 
* @param {string} transferId - The transfer ID.
* @returns {Promise<string>} The transfer status.
*/
async function checkTransferStatus(transferId) {
    const alpacaTransferStatusRequest = Functions.makeHttpRequest({
        method: 'GET',
        url: `https://paper-api.alpaca.markets/v2/wallets/transfers/${transferId}`,
        headers: {
            accept: 'application/json',
            'APCA-API-KEY-ID': secrets.alpacaKey,
            'APCA-API-SECRET-KEY': secrets.alpacaSecret
        }
    });
    const response = await alpacaTransferStatusRequest;
    const { status: transferStatus } = response.data;
    return transferStatus;
} 

/**
* Checks if the Alpaca API keys are set.
* 
* @throws {Error} If the Alpaca API keys are not set.
*/
function _checkKeys() {
    if (!secrets.alpacaKey || !secrets.alpacaSecret) {
        throw Error('need alpaca keys');
    }
}

/**
* Sleeps for a specified amount of milliseconds.
* 
* @param {number} ms - The number of milliseconds to sleep.
* @returns {Promise<void>} A promise that resolves after the specified time.
*/
function sleep(ms) {
    return new Promise(resolve => setTimeout(() => resolve, ms));
}

const result = await main();
return result;