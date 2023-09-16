-include .env

.PHONY: install
install:
	@foundryup
	@forge install OpenZeppelin/openzeppelin-contracts --no-commit

.PHONY: test
test:
	@forge test -vvvv

.PHONY: deploy
deploy:
	@echo "Deploying to Base Mainnet"
	@forge script script/Deploy.s.sol --rpc-url $(BASE_RPC) --private-key $(OWNER_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv

.PHONY: build
build:
	@forge build

.PHONY: format
format:
	@forge fmt