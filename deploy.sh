# Deploy step

# npx hardhat run --network avaxfuji scripts/deployVintageWine.ts
# npx hardhat verify --network avaxfuji

# npx hardhat run --network avaxfuji scripts/deployVintner.ts
# npx hardhat verify --network avaxfuji (--constructor_args: coupenPublic, oracleAddress, BASE_URI)

# npx hardhat run --network avaxfuji scripts/deployUpgrade.ts
# npx hardhat verify --network avaxfuji (--constructor_args: vintageWindAddress, grapeTokenAddress, BASE_URI_UPGRADE)

# npx hardhat run --network avaxfuji scripts/deployCellar.ts
# npx hardhat verify --network avaxfuji (--constructor_args: vintageWindAddress)

# npx hardhat run --network avaxfuji scripts/deployWineryProgression.ts
# npx hardhat verify --network avaxfuji (--constructor_args: grapeTokenAddress)

# npx hardhat run --network avaxfuji scripts/deployWinery.ts
# Go to scan and get proxy contract address
# npx hardhat verify --network avaxfuji (--address: proxy address)

# Update winery contract
# npx hardhat run --network avaxfuji scripts/upgradeWinery.ts

# Deply Grape for only test
# npx hardhat run --network avaxfuji scripts/deployGrape.ts
# npx hardhat verify --network avaxfuji



# // Deploy ALl
# npx hardhat run --network avaxfuji scripts/deployAll.t

echo "DEPLOY"
echo ""
rm -rf cache && rm -rf artifacts
CMD="npx hardhat run --network avaxfuji scripts/deployVintageWine.ts"
echo "CMD: $CMD"
output=`eval $CMD`
echo "output: $output"

echo ""
echo "VERIFY"
echo ""
CMD2="npx hardhat verify --network avaxfuji $output"
echo "CMD2: $CMD2"
output2=`eval $CMD2`
echo "output2: $output2"
