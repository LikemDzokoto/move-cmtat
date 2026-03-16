#!/bin/bash
set -e

IOTA_CMD="iota"
CONFIG_DIR="${HOME}/.iota/iota_config"
NETWORK_ALIAS="move-cmtat-local"

echo "=================================="
echo "Move CMTAT Environment Setup"
echo "=================================="

check_iota_installation() {
    echo ""
    echo "[1/4] Checking IOTA CLI installation..."
    if ! command -v $IOTA_CMD &> /dev/null; then
        echo "ERROR: IOTA CLI not found. Install with:"
        echo "  cargo install iota --locked"
        exit 1
    fi
    echo "✅ IOTA CLI installed: $($IOTA_CMD --version)"
}

initialize_client() {
    echo ""
    echo "[2/4] Initializing IOTA client..."
    if [ ! -d "$CONFIG_DIR" ]; then
        echo "No config found. Running 'iota client' to initialize..."
        $IOTA_CMD client
    else
        echo "✅ Config directory exists"
    fi
}

setup_localnet_env() {
    echo ""
    echo "[3/4] Setting up localnet environment..."
    
    if $IOTA_CMD client env 2>/dev/null | grep -q "localnet"; then
        echo "✅ localnet environment already configured"
    else
        $IOTA_CMD client new-env --rpc "http://127.0.0.1:9000" --alias localnet 2>/dev/null || true
    fi
    
    $IOTA_CMD client switch --env localnet 2>/dev/null || true
}

check_accounts() {
    echo ""
    echo "[4/4] Checking accounts..."
    
    ACTIVE_ADDR=$($IOTA_CMD client active-address 2>/dev/null || echo "")
    
    if [ -z "$ACTIVE_ADDR" ]; then
        echo "No active address. Creating new account..."
        $IOTA_CMD client new-address
        ACTIVE_ADDR=$($IOTA_CMD client active-address)
    fi
    
    echo "Active address: $ACTIVE_ADDR"
    
    BALANCE=$($IOTA_CMD client gas $ACTIVE_ADDR 2>/dev/null | grep "Gas" | awk '{print $2}' || echo "0")
    echo "Balance: $BALANCE"
    
    if [ "$BALANCE" = "0" ] || [ -z "$BALANCE" ]; then
        echo ""
        echo "⚠️  Account has no balance. Run 'iota client faucet' after starting localnet."
    fi
}

display_status() {
    echo ""
    echo "=================================="
    echo "Setup Complete!"
    echo "=================================="
    echo "Active network:"
    $IOTA_CMD client env
    echo ""
    echo "Next steps:"
    echo "  1. Start localnet:  ./scripts/localnet.sh"
    echo "  2. Fund account:   iota client faucet"
    echo "  3. Deploy:         ./scripts/deploy.sh"
}

check_iota_installation
initialize_client
setup_localnet_env
check_accounts
display_status
