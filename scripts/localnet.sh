#!/bin/bash

WATCH_MODE=false
MAX_RETRIES=3
RETRY_DELAY=5
IOTA_PID=""

usage() {
    echo "Usage: $0 [--watch]"
    echo "  --watch    Restart automatically on failure (max 3 retries)"
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --watch)
                WATCH_MODE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
}

cleanup() {
    if [ -n "$IOTA_PID" ] && kill -0 "$IOTA_PID" 2>/dev/null; then
        echo "Stopping localnet (PID: $IOTA_PID)..."
        kill "$IOTA_PID" 2>/dev/null || true
        wait "$IOTA_PID" 2>/dev/null || true
    fi
}

start_localnet() {
    echo "Starting IOTA localnet..."
    RUST_LOG="off,iota_node=info" iota start --force-regenesis --with-faucet &
    IOTA_PID=$!
    echo "Localnet started (PID: $IOTA_PID)"
    
    echo "Waiting for network to be ready..."
    for i in {1..30}; do
        if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9000 2>/dev/null | grep -q "200"; then
            echo "✅ Localnet ready!"
            return 0
        fi
        sleep 2
    done
    
    echo "❌ Localnet failed to start within 60s"
    return 1
}

configure_client() {
    echo "Configuring client..."
    
    if ! iota client env 2>/dev/null | grep -q "localnet"; then
        iota client new-env --rpc "http://127.0.0.1:9000" --alias localnet 2>/dev/null || true
    fi
    
    iota client switch --env localnet 2>/dev/null || true
    
    echo "Funding accounts..."
    iota client faucet 2>/dev/null || echo "Note: Faucet may require manual funding"
}

run_with_watch() {
    local attempt=1
    
    while [ $attempt -le $MAX_RETRIES ]; do
        echo ""
        echo "=================================="
        echo "Attempt $attempt/$MAX_RETRIES"
        echo "=================================="
        
        if start_localnet; then
            configure_client
            
            echo ""
            echo "=================================="
            echo "Localnet running at http://127.0.0.1:9000"
            echo "Press Ctrl+C to stop"
            echo "=================================="
            
            wait $IOTA_PID
            exit_code=$?
            
            if [ $exit_code -eq 0 ]; then
                echo "Localnet stopped normally"
                exit 0
            else
                echo "Localnet crashed with exit code: $exit_code"
            fi
        fi
        
        if [ $attempt -lt $MAX_RETRIES ]; then
            echo "Restarting in ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
            RETRY_DELAY=$((RETRY_DELAY * 2))
            attempt=$((attempt + 1))
        else
            echo "❌ Max retries reached. Exiting."
            exit 1
        fi
    done
}

run_once() {
    if start_localnet; then
        configure_client
        
        echo ""
        echo "=================================="
        echo "Localnet running at http://127.0.0.1:9000"
        echo "Press Ctrl+C to stop"
        echo "=================================="
        
        wait $IOTA_PID
    else
        exit 1
    fi
}

trap cleanup EXIT

parse_args "$@"

if [ "$WATCH_MODE" = true ]; then
    run_with_watch
else
    run_once
fi
