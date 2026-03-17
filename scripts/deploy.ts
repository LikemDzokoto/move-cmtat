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
import { Ed25519Keypair } from '@iota/iota-sdk/keypairs/ed25519';
import { Transaction } from '@iota/iota-sdk/transactions';
import { bcs } from '@iota/iota-sdk/bcs';
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
    private keypair: Ed25519Keypair;
    private config: DeployConfig;

    constructor(config: DeployConfig) {
        this.config = config;
        
        // Initialize IOTA client
        const rpcUrl = this.getRpcUrl(config.network);
        this.client = new IotaClient({ url: rpcUrl });

        // Initialize keypair
        if (config.privateKey) {
            this.keypair = Ed25519Keypair.fromSecretKey(
                Buffer.from(config.privateKey, 'hex')
            );
        } else {
            // Generate new keypair if none provided
            this.keypair = new Ed25519Keypair();
            console.log('⚠️  Generated new keypair. Save this private key:');
            console.log(`Private Key: ${Buffer.from(this.keypair.getSecretKey()).toString('hex')}`);
        }

        console.log(`📍 Deployer Address: ${this.keypair.getPublicKey().toIotaAddress()}`);
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

            // Step 2: Publish the package
            console.log('\n📤 Publishing package to IOTA...');
            const packageId = await this.publishPackage();
            console.log(`✅ Package published: ${packageId}`);

            // Wait for network to index the package
            console.log('⏳ Waiting for package to be indexed...');
            await this.delay(10000);
            console.log('✅ Package indexed');

            // Step 3: Initialize all variants
            console.log('\n🎯 Initializing all variants...');
            const tokenIds = await this.initializeAllTokens(packageId);

            // Step 4: Display summary
            this.displaySummary(packageId, tokenIds);

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

    private async publishPackage(): Promise<string> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        this.configureCliEnvironment();
        
        const networkFlag = this.getNetworkFlag();
        
        const command = `bash -l -c "iota client publish ${networkFlag} --gas-budget 100000000"`;
        
        try {
            const output = execSync(command, execOptions).toString();

            const packageId = this.extractPackageIdFromCliOutput(output);
            if (!packageId) {
                throw new Error('Failed to extract package ID from CLI output');
            }

            return packageId;
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const packageId = this.extractPackageIdFromCliOutput(output);
            if (packageId) {
                return packageId;
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
        if (this.config.network === 'localnet') {
            return '--local';
        }
        return '';
    }

    private extractPackageIdFromCliOutput(output: string): string | null {
        const patterns = [
            /Published Objects:[\s\S]*?ID:\s*(0x[a-fA-F0-9]+)/,
            /package id:\s*(0x[a-fA-F0-9]+)/i,
            /Package ID:\s*(0x[a-fA-F0-9]+)/i,
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
        
        const recipient = config.recipient || this.keypair.getPublicKey().toIotaAddress();
        const moduleName = `${variant}_cmtat`;
        
        const args = [
            config.name,
            config.symbol,
            config.decimals.toString(),
            config.initialSupply.toString(),
            recipient
        ].join(' ');
        
        const command = `bash -l -c "iota client call --package ${packageId} --module ${moduleName} --function init_token --args ${args} --gas-budget 100000000"`;
        
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

    private async initializeToken(packageId: string, variant: string, config: TokenConfig): Promise<string> {
        const tx = new Transaction();
        
        const recipient = config.recipient || this.keypair.getPublicKey().toIotaAddress();
        const moduleName = `${variant}_cmtat`;

        tx.moveCall({
            target: `${packageId}::${moduleName}::init_token`,
            arguments: [
                tx.pure(bcs.string().serialize(config.name).toBytes()),
                tx.pure(bcs.string().serialize(config.symbol).toBytes()),
                tx.pure(bcs.u8().serialize(config.decimals).toBytes()),
                tx.pure(bcs.u64().serialize(config.initialSupply).toBytes()),
                tx.pure(bcs.string().serialize(recipient).toBytes()),
            ],
        });

        const result = await this.client.signAndExecuteTransaction({
            signer: this.keypair,
            transaction: tx,
            options: {
                showEffects: true,
                showObjectChanges: true,
            },
        });

        const tokenId = this.extractTokenId(result);
        if (!tokenId) {
            throw new Error('Failed to extract token ID from transaction result');
        }

        return tokenId;
    }

    private extractPackageId(result: any): string | null {
        const published = result.objectChanges?.filter(
            (change: any) => change.type === 'published'
        );
        return published && published.length > 0 ? published[0].packageId : null;
    }

    private extractTokenId(result: any): string | null {
        const created = result.objectChanges?.filter(
            (change: any) => change.type === 'created' && change.objectType?.includes('CMTAT')
        );
        return created && created.length > 0 ? created[0].objectId : null;
    }

    private displaySummary(packageId: string, tokenIds: Record<string, string>): void {
        console.log('\n================================');
        console.log('✅ Deployment Summary');
        console.log('================================');
        console.log(`Network: ${this.config.network}`);
        console.log(`Package ID: ${packageId}`);
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
