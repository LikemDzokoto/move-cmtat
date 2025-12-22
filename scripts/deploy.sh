#!/bin/bash
# Deploy script for Move CMTAT on IOTA/Sui

set -e

echo "🚀 Starting Move CMTAT Deployment"
echo "=================================="

# Build the project
echo "📦 Building Move CMTAT..."
sui move build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"

# Deploy (requires configured wallet)
echo ""
echo "🔑 Deploying contracts..."
echo "Note: Make sure your wallet is configured and funded"
echo ""

# Publish the package
sui client publish --gas-budget 100000000

echo ""
echo "=================================="
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Note the package ID from above"
echo "2. Initialize tokens using the init_token function"
echo "3. Grant roles as needed"
echo ""
echo "Example initialization:"
echo "sui client call --package <PACKAGE_ID> --module light_cmtat --function init_token \\"
echo "  --args '<name>' '<symbol>' <decimals> <initial_supply> '<recipient>' \\"
echo "  --gas-budget 10000000"
