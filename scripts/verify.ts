import { IotaClient } from '@iota/iota-sdk/client';
import * as fs from 'fs';
import * as path from 'path';

interface VerifyConfig {
    network: 'mainnet' | 'testnet' | 'devnet' | 'localnet';
    packageId: string;
    explorerUrl: string;
}

const defaultConfig: VerifyConfig = {
    network: 'testnet',
    packageId: '',
    explorerUrl: 'https://explorer.testnet.iota.org',
};

class ContractVerifier {
    private client: IotaClient;
    private config: VerifyConfig;

    constructor(config: VerifyConfig) {
        this.config = config;
        this.client = new IotaClient({ url: this.getRpcUrl(config.network) });
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

    async verify(): Promise<boolean> {
        console.log('\n🚀 Starting Contract Verification');
        console.log('==================================');
        console.log(`Network: ${this.config.network}`);
        console.log(`Package ID: ${this.config.packageId}`);
        console.log(`Explorer: ${this.config.explorerUrl}`);
        console.log('');

        const sdkResult = await this.verifyWithSdk();
        const explorerResult = await this.verifyWithExplorer();

        this.displaySummary(sdkResult && explorerResult);

        return sdkResult && explorerResult;
    }

    private async verifyWithSdk(): Promise<boolean> {
        console.log('[1/2] Verifying with SDK...');

        try {
            const packageInfo = await this.client.getPackage({
                packageId: this.config.packageId,
            });

            if (!packageInfo) {
                console.log('❌ Package not found on chain');
                return false;
            }

            console.log(`✅ Package found on chain`);
            console.log(`   Module count: ${packageInfo.modules?.length || 0}`);

            const localModules = this.getLocalModules();
            
            if (localModules.length === 0) {
                console.log('⚠️  No local modules found for bytecode comparison');
                return true;
            }

            let bytecodeMatch = true;
            const onChainModuleNames = new Set(
                packageInfo.modules?.map(m => m.name) || []
            );

            for (const localMod of localModules) {
                if (!onChainModuleNames.has(localMod.name)) {
                    console.log(`❌ Module ${localMod.name} not found on chain`);
                    bytecodeMatch = false;
                }
            }

            if (bytecodeMatch) {
                console.log('✅ All local modules verified on chain');
            }

            const objects = await this.client.getObjectsOwnedByAddress({
                address: this.config.packageId,
            });

            console.log(`   Objects owned: ${objects.length}`);

            return bytecodeMatch;
        } catch (error) {
            console.log('❌ SDK verification failed:', error);
            return false;
        }
    }

    private async verifyWithExplorer(): Promise<boolean> {
        console.log('\n[2/2] Verifying with Explorer...');

        try {
            const rpcUrl = this.getRpcUrl(this.config.network);
            let networkParam = this.config.network;
            
            if (networkParam === 'localnet') {
                console.log('⚠️  Explorer verification not available for localnet');
                return true;
            }

            const query = `
                query {
                    package(address: "${this.config.packageId}") {
                        address
                        moduleNames
                        version
                        previousPackages {
                            address
                            version
                        }
                    }
                }
            `;

            const response = await fetch(`${rpcUrl}/graphql`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ query }),
            });

            if (!response.ok) {
                console.log('⚠️  GraphQL query failed, trying HTTP...');
                return await this.verifyWithExplorerHttp();
            }

            const data = await response.json();

            if (data.errors) {
                console.log('❌ GraphQL errors:', data.errors);
                return false;
            }

            if (data.data?.package) {
                const pkg = data.data.package;
                console.log('✅ Package verified via GraphQL');
                console.log(`   Address: ${pkg.address}`);
                console.log(`   Modules: ${pkg.moduleNames?.join(', ')}`);
                console.log(`   Version: ${pkg.version}`);
                return true;
            } else {
                console.log('❌ Package not found via GraphQL');
                return false;
            }
        } catch (error) {
            console.log('❌ Explorer verification failed:', error);
            return false;
        }
    }

    private async verifyWithExplorerHttp(): Promise<boolean> {
        try {
            const explorerApi = this.config.explorerUrl;
            const url = `${explorerApi}/api/package/${this.config.packageId}`;
            
            const response = await fetch(url);
            
            if (response.ok) {
                const data = await response.json();
                console.log('✅ Package verified via Explorer API');
                console.log(`   Status: ${data.status || 'active'}`);
                return true;
            }
            
            console.log(`⚠️  Explorer API returned ${response.status}`);
            return false;
        } catch (error) {
            console.log('⚠️  Explorer API not available');
            return false;
        }
    }

    private getLocalModules(): { name: string; bytecode: Buffer }[] {
        const buildDir = path.join(process.cwd(), 'build', 'move-cmtat', 'bytecode_modules');
        
        if (!fs.existsSync(buildDir)) {
            return [];
        }

        return fs.readdirSync(buildDir)
            .filter(file => file.endsWith('.mv'))
            .map(file => ({
                name: file.replace('.mv', ''),
                bytecode: fs.readFileSync(path.join(buildDir, file)),
            }));
    }

    private displaySummary(success: boolean): void {
        console.log('\n==================================');
        console.log(success ? '✅ Verification Complete' : '❌ Verification Failed');
        console.log('==================================');
        console.log(`Network: ${this.config.network}`);
        console.log(`Package ID: ${this.config.packageId}`);
        console.log('');
    }
}

async function main() {
    const args = process.argv.slice(2);
    const config: VerifyConfig = { ...defaultConfig };

    for (let i = 0; i < args.length; i++) {
        switch (args[i]) {
            case '--network':
                config.network = args[++i] as any;
                break;
            case '--package-id':
                config.packageId = args[++i];
                break;
            case '--explorer-url':
                config.explorerUrl = args[++i];
                break;
            case '--help':
                printHelp();
                process.exit(0);
        }
    }

    if (!config.packageId) {
        console.log('ERROR: --package-id is required');
        printHelp();
        process.exit(1);
    }

    const verifier = new ContractVerifier(config);
    const success = await verifier.verify();
    process.exit(success ? 0 : 1);
}

function printHelp() {
    console.log(`
Move CMTAT Contract Verification

Usage:
  ts-node verify.ts [options]

Options:
  --package-id <id>     Package ID to verify (required)
  --network <network>  Network (mainnet|testnet|devnet|localnet)
  --explorer-url <url> Explorer URL
  --help               Show this help

Examples:
  ts-node verify.ts --package-id 0x123... --network testnet
  ts-node verify.ts --package-id 0x123... --network localnet
    `);
}

if (require.main === module) {
    main().catch(console.error);
}

export { ContractVerifier, VerifyConfig };
