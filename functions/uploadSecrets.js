const { SecretsManager } = require('@chainlink/functions-toolkit');
const ethers = require('ethers');

/**
* @notice Uploads secrets to the Chainlink DON.
*/
async function uploadSecrets() {
    const routerAddress = getEnvVariable('FUNCTIONS_ROUTER', 'Router address not provided - check your environment variables'); 
    const privateKey = getEnvVariable('PRIVATE_KEY', 'Private key not provided - check your environment variables');
    const rpcUrl = getEnvVariable('SEPOLIA_RPC_URL', 'RPC URL not provided - check your environment variables');
    
    const signer = getSigner(privateKey, rpcUrl);
    const secretsManager = initializeSecretsManager(signer, routerAddress);

    const secrets = getSecrets();
    const encryptedSecretsObj = await secretsManager.encryptSecrets(secrets);
    const gatewayUrls = [process.env.CHAINLINK_ENCRYPTED_SECRET_UPLOAD_ENDPOINT_1, process.env.CHAINLINK_ENCRYPTED_SECRET_UPLOAD_ENDPOINT_2];
    const slotIdNumber = 0;
    const expirationTimeMinutes = 1440;
    
    await uploadToGateways(secretsManager, encryptedSecretsObj.encryptedSecrets, gatewayUrls, slotIdNumber, expirationTimeMinutes);
}

/**
* @notice Gets an environment variable or throws an error if not found.
* @param {string} name - The name of the environment variable.
* @param {string} errorMessage - The error message if the variable is not found.
* @returns {string} - The value of the environment variable.
*/
function getEnvVariable(name, errorMessage) {
    const envValue = process.env[name];
    if (!envValue) {
        throw new Error(errorMessage);
    }
    return envValue;
}

/**
* @notice Gets the secrets from environment variables.
* @returns {Object} - The secrets object.
*/
function getSecrets() {
    return { 'alpacaKey': process.env.ALPACA_API_KEY ?? '', 'aplacaSecret': process.env.ALPACA_SECRET_KEY ?? '' };
}

/**
* @notice Creates and returns a signer.
* @param {string} privateKey - The private key.
* @param {string} rpcUrl - The RPC URL.
* @returns {ethers.Signer} - The signer.
*/
function getSigner(privateKey, rpcUrl) {
    const provider = new ethers.providers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey);
    return wallet.connect(provider);
}

/**
* @notice Initializes and returns the SecretsManager.
* @param {ethers.Signer} signer - The signer.
* @param {string} routerAddress - The router address.
* @returns {SecretsManager} - The initialized SecretsManager.
*/
async function initializeSecretsManager(signer, routerAddress) {
    const secretsManager = new SecretsManager({ 'signer': signer, 'functionsRouterAddress': routerAddress, 'donId': process.env.DON_NETWORK_ID });
    await secretsManager.initialize();
    return secretsManager;
}

/**
* @notice Uploads encrypted secrets to the gateways.
* @param {SecretsManager} secretsManager - The SecretsManager instance.
* @param {string} encryptedSecretsHexstring - The encrypted secrets.
* @param {Array<string>} gatewayUrls - The gateway URLs.
* @param {number} slotId - The slot ID.
* @param {number} minutesUntilExpiration - The expiration time in minutes.
*/
async function uploadToGateways(secretsManager, encryptedSecrets, gatewayUrls, slotIdNumber, expirationTimeMinutes) {
    console.log(`Upload encrypted secret to gateways ${gatewayUrls}. slotId ${slotIdNumber}. Expiration in minutes: ${expirationTimeMinutes}`);
    const uploadResult = await secretsManager.uploadEncryptedSecretsToDON({ 'encryptedSecretsHexstring': encryptedSecrets, 'gatewayUrls': gatewayUrls, 'slotId': slotIdNumber, 'minutesUntilExpiration': expirationTimeMinutes });
    verifyUploadResult(uploadResult);
    logSuccessfullUploadSecrets(uploadResult);
}

/**
* @notice Verifies the result of the secrets upload operation.
* @param {Object} uploadResult - The result object from the secrets upload operation.
* @throws {Error} Throws an error if the upload was not successful.
*/
function verifyUploadResult(uploadResult) {
    if (!uploadResult.success) {
        throw new Error(`Failed to upload secrets: ${uploadResult.errorMessage}`);
    }
}

/**
* @notice Logs the success message and details of the secrets upload operation.
* @param {Object} uploadResult - The result object from the secrets upload operation.
*/
function logSuccessfullUploadSecrets(uploadResult) {
    console.log(`\nSecrets uploaded successfully, response ${uploadResult}`);
    const donHostedSecretsVersion = parseInt(uploadResult.version);
    console.log(`Secrets version: ${donHostedSecretsVersion}`);
}

uploadSecrets().catch(error => {
    console.error(error);
    process.exitCode = 1;
});