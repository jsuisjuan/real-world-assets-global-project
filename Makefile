-include .env
.PHONY: deploy
deploy :; @forge script script/DeployDTsla.s.sol --private-key 575f06450f393506e9d0a1b880d0b2ab8e22cae61afc1fe70b4e77b68e4e355f --rpc-url ${SEPOLIA_RPC_URL} --etherscan-api-key ${ETHERSCAN_API_KEY} --priority-gas-price 1 --verify --broadcast