-include .env

build :; forge build
deploy-sepolia :; forge script ./script/DeployBasicNft.s.sol:DeployBasicNft --rpc-url $(SEPOLIA_RPC_URL) --keystore $(KEYSTORE_PATH_SEPOLIA) --broadcast --verify --etherscan-api-key $(ETHERSCAN_TOKEN)
deploy-anvil :; forge script DeployBasicNft --rpc-url $(RPC_URL) --keystore $(KEYSTORE_PATH) --broadcast -vvv
mintnft-anvil :; forge script ./script/Interactions.s.sol:MintBasicNft --rpc-url $(RPC_URL) --keystore $(KEYSTORE_PATH) --broadcast -vvv
install :; forge install $(GITHUB_REPO_URL) --no-commit
deploy moodnft-anvil :; forge script ./script/DeployDynamicSvg.s.sol:DeployDynamicSvg --rpc-url $(RPC_URL) --keystore $(KEYSTORE_PATH) --broadcast -vvv
