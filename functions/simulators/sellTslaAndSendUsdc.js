const { secrets } = require("../configs/alpacaMintConfig");

const ASSET_TICKER = 'TSLA';
const CRYPTO_TICKER = 'USDCUSD';
const RWA_CONTRACT = '0x7358D4CDF1c468aA018ec41ddD98b44879a10962';
const SLEEP_TIME = 5000;

async function main() {
    const amountTsla = args[0];
    const amountUsdc = args[1];
    _checkKeys();

    // sell TSLA for USD
    let side = 'sell';
    let [client_order_id, orderStatus, responseStatus] = await placeOrder(ASSET_TICKER, amountTsla, side);
    if (responseStatus !== 200) {
        return Functions.encodeUint256(0); 
    }
    if (orderStatus !== 'accepted') {
        return Functions.encodeUint256(0);
    }
    let filled = await waitForOrderToFill(client_order_id);
    if (!filled) {
        await cancelOrder(client_order_id);
        return Functions.encodeUint256(0);
    }

    // buy USDC with USD
    side = 'buy';
    [client_order_id, orderStatus, responseStatus] = await placeOrder(CRYPTO_TICKER, amountTsla, side);
    if (responseStatus !== 200) {
        return Functions.encodeUint256(0);
    }
    if (orderStatus !== 'accepted') {
        return Functions.encodeUint256(0);
    }
    filled = await waitForOrderToFill(client_order_id);
    if (!filled) {
        await cancelOrder(client_order_id);
        return Functions.encodeUint256(0);
    }

    // send USDC to contract
    const transferId = await sendUsdcToContract(amountUsdc);
    if (transferId === null) {
        return Functions.encodeUint256(0);
    }
    const completed = await waitForCryptoTransferToComplete(transferId);
    if (!completed) {
        return Functions.encodeUint256(0);
    }
    return Functions.encodeUint256(amountUsdc);
}

async function placeOrder(symbol, qty, side) {
    const alpacaSellRequest = Functions.makeHttpRequest({
        'method': 'POST',
        'url': 'https://paper-api.alpaca.markets/v2/orders',
        'headers': {
            'accept': 'application/json',
            'content-type': 'application/json',
            'APCA-API-KEY-ID': secrets.alpacaKey,
            'APCA-API-SECRET-KEY': secrets.alpacaSecret
        },
        'data': {
            'side': side,
            'type': 'market',
            'time_in_force': 'gtc',
            'symbol': symbol,
            'qty': qty
        }
    });
    const [response] = await Promise.all([alpacaSellRequest]);
    const responseStatus = response.status;

    console.log(`\nResponse status: ${responseStatus}\n`);
    console.log(response);
    console.log(`\n`);

    const { client_order_id, 'status': orderStatus } = response.data;
    return client_order_id, orderStatus, responseStatus;
}

async function cancelOrder(client_order_id) {
    const alpacaCancelRequest = Functions.makeHttpRequest({
        'method': 'DELETE',
        'url': `https://paper-api.alpaca.markets/v2/orders/${client_order_id}`,
        'headers': {
            'accept': 'application/json',
            'APCA-API-KEY-ID': secrets.alpacaKey,
            'APCA-API-SECRET-KEY': secrets.alpacaSecret
        }
    });
    const [response] = await Promise.all([alpacaCancelRequest]);
    const responseStatus = response.status;
    return responseStatus;
}

async function waitForOrderToFill(client_order_id) {
    const capNumberOfSleeps = 10;
    let numberOfSleeps = 0;
    let filled = false;
    while (numberOfSleeps < capNumberOfSleeps) {
        const alpacaOrderStatusRequest = Functions.makeHttpRequest({
            'method': 'GET',
            'url': `https://paper-api.alpaca.markets/v2/orders/${client_order_id}`,
            'headers': {
                'accept': 'application/json',
                'APCA-API-KEY-ID': secrets.alpacaKey,
                'APCA-API-SECRET-KEY': secrets.alpacaSecret
            }
        });
        const [response] = await Promise.all([alpacaOrderStatusRequest]);
        const responseStatus = response.status;
        const { 'status': orderStatus } = response.data;
        if (responseStatus !== 200) {
            return false;
        }
        if (orderStatus === 'filled') {
            filled = true;
            break;
        }
        numberOfSleeps++;
        await sleep(SLEEP_TIME);
    }
    return filled;
}

async function sendUsdcToContract(usdcAmount) {
    const transferRequest = Functions.makeHttpRequest({
        'method': 'POST',
        'url': 'https://paper-api.alpaca.markets/v2/wallets/transfers',
        'headers': {
            'accept': 'application/json',
            'content-type': 'application/json',
            'APCA-API-KEY-ID': secrets.alpacaKey,
            'APCA-API-SECRET-KEY': secrets.alpacaSecret
        },
        'data': {
            'amount': usdcAmount,
            'address': RWA_CONTRACT,
            'asset': CRYPTO_TICKER
        }
    });
    const [response] = await Promise.all([transferRequest]);
    if (response.status !== 200) {
        return null;
    }
    return response.data.id;
}

async function waitForCryptoTransferToComplete(transferId) {
    const capNumberOfSleeps = 120;
    let numberOfSleeps = 0;
    let completed = false;
    while (numberOfSleeps < capNumberOfSleeps) {
        const alpacaTransferStatusRequest = Functions.makeHttpRequest({
            'method': 'GET',
            'url': `https://paper-api.alpaca.markets/v2/wallets/transfers/${transferId}`,
            'headers': {
                'accept': 'application/json',
                'APCA-API-KEY-ID': secrets.alpacaKey,
                'APCA-API-SECRET-KEY': secrets.alpacaSecret
            }
        });
        const [response] = await Promise.all([alpacaTransferStatusRequest]);
        const responseStatus = response.status;
        const { 'status': transferStatus } = response.data;
        if (responseStatus !== 200) {
            return false;
        }
        if (transferStatus === 'completed') {
            completed = true;
            break;
        }
        numberOfSleeps++;
        await sleep(SLEEP_TIME); 
    }
    return completed;
}

function _checkKeys() {
    if (secrets.alpacaKey === '' || secrets.alpacaSecret === '') {
        throw Error('need alpaca keys');
    }
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(() => resolve, ms));
}

const result = await main();
return result;