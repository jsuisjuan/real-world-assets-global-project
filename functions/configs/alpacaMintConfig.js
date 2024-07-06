const fs = require('fs');
const { Location, ReturnType, CodeLanguage } = require('@chainlink/functions-toolkit');

const requestConfig = {
    'source': fs.readFileSync('./functions/source/alpacaBalance.js').toString(),
    'codeLocation': Location.Inline,
    'secrets': {
        'alpacaKey': process.env.ALPACA_API_KEY,
        'alpacaSecret': process.env.ALPACA_SECRET_KEY
    },
    'secretsLocation': Location.DONHosted,
    'args': [],
    'codeLanguage': CodeLanguage.JavaScript,
    'expectedReturnType': ReturnType.uint256
};

module.exports = requestConfig;

// parei em 1:24:58, script não está rodando, talvez seja a versão do node...