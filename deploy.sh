# npx hardhat run --network avaxfuji scripts/deployGrape.ts
# npx hardhat verify --network avaxfuji

echo "DEPLOY"
echo ""
rm -rf cache && rm -rf artifacts
CMD="npx hardhat run --network avaxfuji scripts/deployGrape.ts"
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