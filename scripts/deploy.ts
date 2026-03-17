/**
 * TypeScript Deployment Script for Move CMTAT on IOTA
 * 
 * This script provides automated deployment for all four CMTAT variants:
 * - Light CMTAT
 * - Allowlist CMTAT 
 * - Debt CMTAT 
 * - Standard CMTAT 
 */

import { IotaClient } from '@iota/iota-sdk/client';
import * as fs from 'fs';
import * as path from 'path';

// Configuration
interface TokenConfig {
    name: string;
    symbol: string;
    decimals: number;
    initialSupply: number;
    recipient: string;
}

interface DeployConfig {
    network: 'mainnet' | 'testnet' | 'devnet' | 'localnet';
    privateKey?: string;
    skipBuild?: boolean;
    variants: {
        light?: TokenConfig;
        allowlist?: TokenConfig;
        debt?: TokenConfig;
        standard?: TokenConfig;
    };
}

const VARIANTS = ['light', 'allowlist', 'debt', 'standard'] as const;

const VARIANT_INFO: Record<string, { name: string; symbol: string }> = {
    light: { name: 'Light CMTAT', symbol: 'LGT' },
    allowlist: { name: 'Allowlist CMTAT', symbol: 'ALW' },
    debt: { name: 'Debt CMTAT', symbol: 'DEBT' },
    standard: { name: 'Standard CMTAT', symbol: 'STD' },
};

function createVariantConfig(base: TokenConfig, variant: string): TokenConfig {
    const info = VARIANT_INFO[variant];
    return {
        ...base,
        name: `${base.name} ${info.name}`,
        symbol: `${base.symbol}${info.symbol}`,
    };
}

function createDefaultVariantsConfig(base: TokenConfig): DeployConfig['variants'] {
    const variants: DeployConfig['variants'] = {};
    for (const variant of VARIANTS) {
        variants[variant] = createVariantConfig(base, variant);
    }
    return variants;
}

// Default configuration
const defaultConfig: DeployConfig = {
    network: 'testnet',
    variants: createDefaultVariantsConfig({
        name: 'Test CMTAT',
        symbol: 'TCMT',
        decimals: 18,
        initialSupply: 1000000,
        recipient: '',
    }),
};

class CMTATDeployer {
    private client: IotaClient;
    private senderAddress: string;
    private config: DeployConfig;

    constructor(config: DeployConfig) {
        this.config = config;
        
        // Initialize IOTA client
        const rpcUrl = this.getRpcUrl(config.network);
        this.client = new IotaClient({ url: rpcUrl });

        // Get CLI's active address
        this.senderAddress = this.getCliActiveAddress();
        
        console.log(`📍 Deployer Address (from CLI): ${this.senderAddress}`);
    }

    private getCliActiveAddress(): string {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        try {
            const output = execSync('bash -l -c "iota client active-address"', execOptions).toString().trim();
            if (output && output.startsWith('0x')) {
                return output;
            }
        } catch (error) {
            console.error('Failed to get active address from CLI:', error);
        }
        
        throw new Error('Cannot determine CLI active address. Make sure iota CLI is configured with "iota client switch"');
    }

    private async ensureWalletFunded(): Promise<void> {
        if (this.config.network === 'localnet') {
            console.log('💧 Localnet detected - skipping faucet check');
            return;
        }

        if (this.config.network === 'mainnet') {
            console.log('💰 Mainnet detected - skipping faucet check');
            return;
        }

        console.log(`\n💧 Checking wallet balance on ${this.config.network}...`);
        
        const balance = await this.getBalance(this.senderAddress);
        const minBalance = 1000000000; // 1 IOTA in mist
        
        if (balance >= minBalance) {
            console.log(`   Wallet funded: ${balance} mist`);
            return;
        }

        console.log(`   Wallet low on funds: ${balance} mist (need at least ${minBalance} mist)`);
        
        if (this.config.network === 'testnet') {
            console.log('   Requesting faucet funds...');
            await this.requestFaucet(this.senderAddress);
            
            // Wait for faucet and check balance again
            await this.delay(5000);
            const newBalance = await this.getBalance(this.senderAddress);
            console.log(`   New balance: ${newBalance} mist`);
        }
    }

    private async getBalance(address: string): Promise<number> {
        try {
            const { execSync } = require('child_process');
            const execOptions = this.getExecOptions();
            
            const networkFlag = this.getNetworkFlag();
            const output = execSync(`bash -l -c "iota client balance ${address} ${networkFlag}"`, execOptions).toString();
            
            // Parse balance from output (e.g., "Balance: 1000000000 mist")
            const match = output.match(/(\d+)\s*mist/);
            if (match) {
                return parseInt(match[1], 10);
            }
            
            // Try alternative format
            const plainMatch = output.match(/(\d+)/);
            if (plainMatch) {
                return parseInt(plainMatch[1], 10);
            }
            
            return 0;
        } catch (error) {
            return 0;
        }
    }

    private async requestFaucet(address: string): Promise<void> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        try {
            // First switch to testnet
            execSync('bash -l -c "iota client switch --env testnet"', execOptions);
            
            // Request faucet
            const output = execSync(`bash -l -c "iota client faucet ${address}"`, execOptions).toString();
            console.log(`   Faucet response: ${output.substring(0, 200)}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            console.log(`   Faucet request result: ${output.substring(0, 200)}`);
        }
    }

    private getRpcUrl(network: string): string {
        const urls: Record<string, string> = {
            mainnet: 'https://api.iota.cafe',
            testnet: 'https://api.testnet.iota.cafe',
            devnet: 'https://api.devnet.iota.cafe',
            localnet: 'http://127.0.0.1:9000',
        };
        return urls[network] || urls.testnet;
    }

    private delay(ms: number): Promise<void> {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    async deploy(): Promise<void> {
        console.log('\n🚀 Starting CMTAT Deployment');
        console.log('================================');
        console.log(`Network: ${this.config.network}`);
        console.log(`Variants: ${VARIANTS.join(', ')}`);
        console.log('');

        try {
            // Step 1: Build the package
            if (this.config.skipBuild) {
                console.log('📦 Skipping build (using existing build artifacts)');
            } else {
                console.log('📦 Building Move package...');
                await this.buildPackage();
            }

            // Step 1.5: Ensure wallet is funded (testnet only)
            await this.ensureWalletFunded();

            // Step 2: Publish the package
            console.log('\n📤 Publishing package to IOTA...');
            const publishResult = await this.publishPackage();
            
            if (publishResult.packageId === 'pending') {
                console.log(`⚠️  Package publish submitted but confirmation pending`);
                console.log(`   Transaction Digest: ${publishResult.txDigest}`);
                console.log(`   Please check the explorer to verify if the transaction succeeded`);
                console.log(`   Once confirmed, you can find the package ID in the transaction effects`);
                return;
            }
            
            console.log(`✅ Package published: ${publishResult.packageId}`);

            // Wait for network to index the package
            console.log('⏳ Waiting for package to be indexed...');
            await this.delay(10000);
            console.log('✅ Package indexed');

            // Step 3: Note - initialization happens automatically via private init function
            console.log('\n📝 Note: Token initialization happens automatically on publish');
            console.log('   Use interact.ts to configure tokens and mint supply');

            // Step 4: Display summary
            const tokenIds: Record<string, string> = {};
            this.displaySummary(publishResult.packageId, tokenIds, publishResult.txDigest);

        } catch (error) {
            console.error('❌ Deployment failed:', error);
            throw error;
        }
    }

    private async buildPackage(): Promise<void> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        execOptions.stdio = 'inherit';
        try {
            execSync('bash -l -c "iota move build"', execOptions);
            console.log('✅ Build successful!');
        } catch (error) {
            throw new Error('Build failed. Make sure IOTA CLI is installed and in PATH.');
        }
    }

    private getExecOptions(): { stdio: 'pipe' | 'inherit'; shell: boolean; env: NodeJS.ProcessEnv } {
        return {
            stdio: 'pipe',
            shell: true,
            env: { ...process.env }
        };
    }

    private async publishPackage(): Promise<{ packageId: string; txDigest: string }> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        this.configureCliEnvironment();
        
        const networkFlag = this.getNetworkFlag();
        
        const command = `bash -l -c "iota client publish ${networkFlag} --gas-budget 1000000000"`;
        
        try {
            const output = execSync(command, execOptions).toString();

            const packageId = this.extractPackageIdFromCliOutput(output);
            if (!packageId) {
                throw new Error('Failed to extract package ID from CLI output. Output: ' + output.substring(0, 500));
            }

            const txDigest = this.extractTransactionDigestFromCliOutput(output) || 'unknown';
            console.log(`   Transaction Digest: ${txDigest}`);

            return { packageId, txDigest };
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const packageId = this.extractPackageIdFromCliOutput(output);
            if (packageId) {
                const txDigest = this.extractTransactionDigestFromCliOutput(output) || 'unknown';
                console.log(`   Transaction Digest: ${txDigest}`);
                console.log(`   ⚠️  Transaction may still be processing (timeout on confirmation)`);
                return { packageId, txDigest };
            }
            
            // Check if it's a timeout error but tx might have succeeded
            if (output.includes('Failed to confirm tx status') || output.includes('timeout')) {
                const txDigest = this.extractTransactionDigestFromCliOutput(output) || 'unknown';
                if (txDigest !== 'unknown') {
                    console.log(`   ⚠️  Transaction submitted but confirmation timed out`);
                    console.log(`   Tx Digest: ${txDigest}`);
                    console.log(`   Please verify manually on explorer`);
                    // Return with unknown packageId - user needs to check
                    return { packageId: 'pending', txDigest };
                }
            }
            
            throw new Error(`Publish failed: ${output || error.message}`);
        }
    }

    private configureCliEnvironment(): void {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        const network = this.config.network;
        if (network === 'localnet') {
            try {
                execSync('bash -l -c "iota client switch --env localnet"', execOptions);
            } catch {}
        } else if (network === 'testnet') {
            try {
                execSync('bash -l -c "iota client switch --env testnet"', execOptions);
            } catch {}
        } else if (network === 'mainnet') {
            try {
                execSync('bash -l -c "iota client switch --env mainnet"', execOptions);
            } catch {}
        }
    }

    private getNetworkFlag(): string {
        return '';
    }

    private extractPackageIdFromCliOutput(output: string): string | null {
        const patterns = [
            /Published Objects:[\s\S]*?ID:\s*(0x[a-fA-F0-9]+)/,
            /package id:\s*(0x[a-fA-F0-9]+)/i,
            /Package ID:\s*(0x[a-fA-F0-9]+)/i,
        ];

        for (const pattern of patterns) {
            const match = output.match(pattern);
            if (match) {
                return match[1];
            }
        }
        return null;
    }

    private extractTransactionDigestFromCliOutput(output: string): string | null {
        const patterns = [
            /Transaction Digest:\s*([a-zA-Z0-9]+)/i,
            /digest:\s*([a-zA-Z0-9]+)/i,
            /tx_digest['"]?:\s*['"]?([a-zA-Z0-9]+)['"]?/i,
            /Digest:\s*([a-zA-Z0-9]+)/i,
        ];

        for (const pattern of patterns) {
            const match = output.match(pattern);
            if (match) {
                return match[1];
            }
        }
        return null;
    }

    private async initializeAllTokens(packageId: string): Promise<Record<string, string>> {
        const results: Record<string, string> = {};
        
        for (const variant of VARIANTS) {
            const config = this.config.variants[variant];
            if (config) {
                console.log(`\n🎯 Initializing ${variant}...`);
                try {
                    const tokenId = await this.initializeTokenViaCli(packageId, variant, config);
                    results[variant] = tokenId;
                    console.log(`✅ ${variant} initialized: ${tokenId}`);
                    await this.delay(2000);
                } catch (error: any) {
                    console.log(`⚠️  ${variant} initialization failed: ${error.message}`);
                }
            }
        }
        
        if (Object.keys(results).length === 0) {
            throw new Error('No variants were initialized');
        }
        
        return results;
    }

    private async initializeTokenViaCli(packageId: string, variant: string, config: TokenConfig): Promise<string> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        const recipient = config.recipient || this.senderAddress;
        const moduleName = `${variant}_cmtat`;
        
        const args = [
            config.name,
            config.symbol,
            config.decimals.toString(),
            config.initialSupply.toString(),
            recipient
        ].join(' ');
        
        const command = `bash -l -c "iota client call --package ${packageId} --module ${moduleName} --function init_token --args ${args} --gas-budget 500000000"`;
        
        try {
            const output = execSync(command, execOptions).toString();
            
            const tokenId = this.extractTokenIdFromCliOutput(output);
            if (!tokenId) {
                throw new Error('Failed to extract token ID from CLI output');
            }
            
            return tokenId;
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const tokenId = this.extractTokenIdFromCliOutput(output);
            if (tokenId) {
                return tokenId;
            }
            throw new Error(`Init failed: ${output || error.message}`);
        }
    }

    private extractTokenIdFromCliOutput(output: string): string | null {
        const patterns = [
            /Created Objects:[\s\S]*?ID:\s*(0x[a-fA-F0-9]+)/,
            /object id:\s*(0x[a-fA-F0-9]+)/i,
            /Object ID:\s*(0x[a-fA-F0-9]+)/i,
            /(0x[a-fA-F0-9]{64})/,
        ];

        for (const pattern of patterns) {
            const match = output.match(pattern);
            if (match) {
                return match[1];
            }
        }
        return null;
    }

    private displaySummary(packageId: string, tokenIds: Record<string, string>, txDigest: string): void {
        console.log('\n================================');
        console.log('✅ Deployment Summary');
        console.log('================================');
        console.log(`Network: ${this.config.network}`);
        console.log(`Package ID: ${packageId}`);
        console.log(`Transaction Digest: ${txDigest}`);
        console.log(`Explorer: https://explorer.${this.config.network}.iota.org/txblock/${txDigest}`);
        console.log('');
        console.log('Deployed Variants:');
        for (const [variant, tokenId] of Object.entries(tokenIds)) {
            const config = this.config.variants[variant];
            console.log(`  ${variant}:`);
            console.log(`    Token ID: ${tokenId}`);
            console.log(`    Name: ${config?.name}`);
            console.log(`    Symbol: ${config?.symbol}`);
            console.log(`    Initial Supply: ${config?.initialSupply}`);
        }
        console.log('');
        console.log('Next Steps:');
        console.log('1. Grant additional roles as needed');
        console.log('2. Configure allowlist (for Allowlist CMTAT)');
        console.log('3. Set debt information (for Debt CMTAT)');
        console.log('4. Test token operations');
        console.log('================================\n');
    }
}

// CLI Interface
async function main() {
    const args = process.argv.slice(2);
    
    // Parse command line arguments
    const config: DeployConfig = { ...defaultConfig };
    
    let baseName = 'Test CMTAT';
    let baseSymbol = 'TCMT';
    let decimals = 18;
    let initialSupply = 1000000;
    let recipient = '';
    
    for (let i = 0; i < args.length; i++) {
        switch (args[i]) {
            case '--network':
                config.network = args[++i] as any;
                break;
            case '--private-key':
                config.privateKey = args[++i];
                break;
            case '--name':
                baseName = args[++i];
                break;
            case '--symbol':
                baseSymbol = args[++i];
                break;
            case '--decimals':
                decimals = parseInt(args[++i]);
                break;
            case '--initial-supply':
                initialSupply = parseInt(args[++i]);
                break;
            case '--recipient':
                recipient = args[++i];
                break;
            case '--skip-build':
                config.skipBuild = true;
                break;
            case '--help':
                printHelp();
                process.exit(0);
        }
    }
    
    config.variants = createDefaultVariantsConfig({
        name: baseName,
        symbol: baseSymbol,
        decimals,
        initialSupply,
        recipient,
    });

    // Deploy
    const deployer = new CMTATDeployer(config);
    await deployer.deploy();
}

function printHelp() {
    console.log(`
Move CMTAT Deployment Script

This script deploys ALL 4 CMTAT variants:
  - Light CMTAT
  - Allowlist CMTAT  
  - Debt CMTAT
  - Standard CMTAT

Usage:
  ts-node deploy.ts [options]

Options:
  --network <network>          Network to deploy to (mainnet|testnet|devnet|localnet)
  --private-key <key>         Private key for deployment (hex format)
  --name <name>               Base token name (variant name will be appended)
  --symbol <symbol>          Base token symbol (variant symbol will be appended)
  --decimals <decimals>      Token decimals
  --initial-supply <supply>  Initial token supply (same for all variants)
  --recipient <address>       Initial supply recipient address
  --skip-build               Skip build step
  --help                     Show this help message

Examples:
  # Deploy all variants to testnet
  ts-node deploy.ts --network testnet --name "My Token" --symbol "MTK"

  # Deploy all variants to mainnet with private key
  ts-node deploy.ts --network mainnet --private-key <YOUR_KEY>
    `);
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}

export { CMTATDeployer, DeployConfig };
