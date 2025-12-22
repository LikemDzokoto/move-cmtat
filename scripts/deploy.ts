/**
 * TypeScript Deployment Script for Move CMTAT on IOTA
 * 
 * This script provides automated deployment for all four CMTAT variants:
 * - Light CMTAT (4 roles)
 * - Allowlist CMTAT (9 roles)
 * - Debt CMTAT (10 roles)
 * - Standard CMTAT (9 roles)
 */

import { IotaClient, IotaTransactionBlockResponse } from '@iota/iota-sdk/client';
import { Ed25519Keypair } from '@iota/iota-sdk/keypairs/ed25519';
import { TransactionBlock } from '@iota/iota-sdk/transactions';
import * as fs from 'fs';
import * as path from 'path';

// Configuration
interface DeployConfig {
    network: 'mainnet' | 'testnet' | 'devnet' | 'localnet';
    privateKey?: string;
    variant: 'light' | 'allowlist' | 'debt' | 'standard';
    tokenConfig: {
        name: string;
        symbol: string;
        decimals: number;
        initialSupply: number;
        recipient: string;
    };
}

// Default configuration
const defaultConfig: DeployConfig = {
    network: 'testnet',
    variant: 'light',
    tokenConfig: {
        name: 'Test CMTAT Token',
        symbol: 'TCMT',
        decimals: 18,
        initialSupply: 1000000,
        recipient: '', // Will be set to deployer address
    },
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
        const urls = {
            mainnet: 'https://api.mainnet.iota.org:443',
            testnet: 'https://api.testnet.iota.org:443',
            devnet: 'https://api.devnet.iota.org:443',
            localnet: 'http://127.0.0.1:9000',
        };
        return urls[network] || urls.testnet;
    }

    async deploy(): Promise<void> {
        console.log('\n🚀 Starting CMTAT Deployment');
        console.log('================================');
        console.log(`Network: ${this.config.network}`);
        console.log(`Variant: ${this.config.variant}`);
        console.log('');

        try {
            // Step 1: Build the package
            console.log('📦 Building Move package...');
            await this.buildPackage();

            // Step 2: Publish the package
            console.log('\n📤 Publishing package to IOTA...');
            const packageId = await this.publishPackage();
            console.log(`✅ Package published: ${packageId}`);

            // Step 3: Initialize token
            console.log('\n🎯 Initializing token...');
            const tokenId = await this.initializeToken(packageId);
            console.log(`✅ Token initialized: ${tokenId}`);

            // Step 4: Display summary
            this.displaySummary(packageId, tokenId);

        } catch (error) {
            console.error('❌ Deployment failed:', error);
            throw error;
        }
    }

    private async buildPackage(): Promise<void> {
        const { execSync } = require('child_process');
        try {
            execSync('iota move build', { stdio: 'inherit' });
            console.log('✅ Build successful!');
        } catch (error) {
            throw new Error('Build failed. Make sure IOTA CLI is installed.');
        }
    }

    private async publishPackage(): Promise<string> {
        const tx = new TransactionBlock();
        
        // Read compiled modules
        const modulesDir = path.join(process.cwd(), 'build', 'move-cmtat', 'bytecode_modules');
        const modules = fs.readdirSync(modulesDir)
            .filter(file => file.endsWith('.mv'))
            .map(file => {
                const modulePath = path.join(modulesDir, file);
                return Array.from(fs.readFileSync(modulePath));
            });

        // Publish package
        const [upgradeCap] = tx.publish({
            modules,
            dependencies: [],
        });

        // Transfer upgrade capability to sender
        tx.transferObjects([upgradeCap], tx.pure(this.keypair.getPublicKey().toIotaAddress()));

        // Execute transaction
        const result = await this.client.signAndExecuteTransactionBlock({
            signer: this.keypair,
            transactionBlock: tx,
            options: {
                showEffects: true,
                showObjectChanges: true,
            },
        });

        // Extract package ID from created objects
        const packageId = this.extractPackageId(result);
        if (!packageId) {
            throw new Error('Failed to extract package ID from transaction result');
        }

        return packageId;
    }

    private async initializeToken(packageId: string): Promise<string> {
        const tx = new TransactionBlock();
        
        // Set recipient to deployer if not specified
        const recipient = this.config.tokenConfig.recipient || 
                         this.keypair.getPublicKey().toIotaAddress();

        // Get module name based on variant
        const moduleName = `${this.config.variant}_cmtat`;

        // Call init_token function
        tx.moveCall({
            target: `${packageId}::${moduleName}::init_token`,
            arguments: [
                tx.pure(this.config.tokenConfig.name),
                tx.pure(this.config.tokenConfig.symbol),
                tx.pure(this.config.tokenConfig.decimals),
                tx.pure(this.config.tokenConfig.initialSupply),
                tx.pure(recipient),
            ],
        });

        // Execute transaction
        const result = await this.client.signAndExecuteTransactionBlock({
            signer: this.keypair,
            transactionBlock: tx,
            options: {
                showEffects: true,
                showObjectChanges: true,
            },
        });

        // Extract token object ID
        const tokenId = this.extractTokenId(result);
        if (!tokenId) {
            throw new Error('Failed to extract token ID from transaction result');
        }

        return tokenId;
    }

    private extractPackageId(result: IotaTransactionBlockResponse): string | null {
        const created = result.objectChanges?.filter(
            change => change.type === 'published'
        );
        return created && created.length > 0 ? created[0].packageId : null;
    }

    private extractTokenId(result: IotaTransactionBlockResponse): string | null {
        const created = result.objectChanges?.filter(
            change => change.type === 'created' && change.objectType.includes('CMTAT')
        );
        return created && created.length > 0 ? created[0].objectId : null;
    }

    private displaySummary(packageId: string, tokenId: string): void {
        console.log('\n================================');
        console.log('✅ Deployment Summary');
        console.log('================================');
        console.log(`Network: ${this.config.network}`);
        console.log(`Variant: ${this.config.variant.toUpperCase()} CMTAT`);
        console.log(`Package ID: ${packageId}`);
        console.log(`Token ID: ${tokenId}`);
        console.log('');
        console.log('Token Configuration:');
        console.log(`  Name: ${this.config.tokenConfig.name}`);
        console.log(`  Symbol: ${this.config.tokenConfig.symbol}`);
        console.log(`  Decimals: ${this.config.tokenConfig.decimals}`);
        console.log(`  Initial Supply: ${this.config.tokenConfig.initialSupply}`);
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
    
    for (let i = 0; i < args.length; i++) {
        switch (args[i]) {
            case '--network':
                config.network = args[++i] as any;
                break;
            case '--variant':
                config.variant = args[++i] as any;
                break;
            case '--private-key':
                config.privateKey = args[++i];
                break;
            case '--name':
                config.tokenConfig.name = args[++i];
                break;
            case '--symbol':
                config.tokenConfig.symbol = args[++i];
                break;
            case '--decimals':
                config.tokenConfig.decimals = parseInt(args[++i]);
                break;
            case '--initial-supply':
                config.tokenConfig.initialSupply = parseInt(args[++i]);
                break;
            case '--recipient':
                config.tokenConfig.recipient = args[++i];
                break;
            case '--help':
                printHelp();
                process.exit(0);
        }
    }

    // Deploy
    const deployer = new CMTATDeployer(config);
    await deployer.deploy();
}

function printHelp() {
    console.log(`
Move CMTAT Deployment Script

Usage:
  ts-node deploy.ts [options]

Options:
  --network <network>          Network to deploy to (mainnet|testnet|devnet|localnet)
  --variant <variant>          CMTAT variant (light|allowlist|debt|standard)
  --private-key <key>          Private key for deployment (hex format)
  --name <name>                Token name
  --symbol <symbol>            Token symbol
  --decimals <decimals>        Token decimals
  --initial-supply <supply>    Initial token supply
  --recipient <address>        Initial supply recipient address
  --help                       Show this help message

Examples:
  # Deploy Light CMTAT to testnet
  ts-node deploy.ts --network testnet --variant light --name "My Token" --symbol "MTK"

  # Deploy Allowlist CMTAT with custom config
  ts-node deploy.ts --variant allowlist --name "Security Token" --symbol "SEC" --initial-supply 1000000

  # Deploy Debt CMTAT to mainnet with private key
  ts-node deploy.ts --network mainnet --variant debt --private-key <YOUR_KEY>
    `);
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}

export { CMTATDeployer, DeployConfig };
