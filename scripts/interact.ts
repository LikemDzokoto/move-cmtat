interface InteractConfig {
    network: 'mainnet' | 'testnet' | 'devnet' | 'localnet';
    privateKey?: string;
    packageId: string;
    variant: 'light' | 'allowlist' | 'debt' | 'standard';
    action: string;
    amount?: number;
    recipient?: string;
    address?: string;
    role?: string;
}

const defaultConfig: InteractConfig = {
    network: 'testnet',
    variant: 'light',
    action: '',
    packageId: '',
};

class TokenInteractor {
    private senderAddress: string;
    private config: InteractConfig;

    constructor(config: InteractConfig) {
        this.config = config;
        
        // Switch to the correct network first
        this.switchNetwork(config.network);
        
        this.senderAddress = this.getCliActiveAddress();
        console.log(`📍 Signer Address (from CLI): ${this.senderAddress}`);
    }

    private switchNetwork(network: string): void {
        if (network === 'localnet' || network === 'mainnet') {
            return;
        }
        
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        try {
            execSync(`bash -l -c "iota client switch --env ${network}"`, execOptions);
        } catch (error) {
            // Ignore if already on the correct network
        }
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

    private getExecOptions(): any {
        return {
            stdio: ['pipe', 'pipe', 'pipe'],
            maxBuffer: 50 * 1024 * 1024,
        };
    }

    private getNetworkFlag(): string {
        return `--env ${this.config.network}`;
    }

    private async ensureWalletFunded(): Promise<void> {
        if (this.config.network === 'localnet' || this.config.network === 'mainnet') {
            return;
        }

        console.log(`\n💧 Checking wallet balance on ${this.config.network}...`);
        
        const balance = await this.getWalletBalance(this.senderAddress);
        const minBalance = 1000000000;
        
        if (balance >= minBalance) {
            console.log(`   Wallet funded: ${balance} mist`);
            return;
        }

        console.log(`   Wallet low on funds: ${balance} mist (need at least ${minBalance} mist)`);
        
        if (this.config.network === 'testnet') {
            console.log('   Requesting faucet funds...');
            await this.requestFaucet(this.senderAddress);
            await this.delay(5000);
            const newBalance = await this.getWalletBalance(this.senderAddress);
            console.log(`   New balance: ${newBalance} mist`);
        }
    }

    private async getWalletBalance(address: string): Promise<number> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        try {
            const output = execSync(`bash -l -c "iota client balance ${address}"`, execOptions).toString();
            const match = output.match(/(\d+)\s*mist/);
            if (match) {
                return parseInt(match[1], 10);
            }
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
            execSync('bash -l -c "iota client switch --env testnet"', execOptions);
            const output = execSync(`bash -l -c "iota client faucet --address ${address}"`, execOptions).toString();
            console.log(`   Faucet response: ${output.substring(0, 200)}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            console.log(`   Faucet request result: ${output.substring(0, 200)}`);
        }
    }

    private delay(ms: number): Promise<void> {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    async run(): Promise<void> {
        await this.ensureWalletFunded();

        console.log('\n🚀 Token Interaction');
        console.log('==================================');
        console.log(`Network: ${this.config.network}`);
        console.log(`Action: ${this.config.action}`);
        console.log(`Package: ${this.config.packageId}`);
        console.log(`Signer: ${this.senderAddress}`);
        console.log('');

        const actions: Record<string, () => Promise<void>> = {
            mint: () => this.mint(),
            burn: () => this.burn(),
            transfer: () => this.transfer(),
            pause: () => this.pause(),
            unpause: () => this.unpause(),
            freeze: () => this.freeze(),
            unfreeze: () => this.unfreeze(),
            grant_role: () => this.grantRole(),
            revoke_role: () => this.revokeRole(),
            balance: () => this.getBalance(),
            info: () => this.getTokenInfo(),
        };

        const actionFn = actions[this.config.action];
        if (!actionFn) {
            console.log(`Unknown action: ${this.config.action}`);
            console.log(`Available: ${Object.keys(actions).join(', ')}`);
            process.exit(1);
        }

        await actionFn();
    }

    private async mint(): Promise<void> {
        if (!this.config.amount || !this.config.recipient) {
            console.log('ERROR: --amount and --recipient required for mint');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        const moduleName = `${this.config.variant}_cmtat`;
        const args = `${this.config.recipient} ${this.config.amount}`;
        
        const command = `bash -l -c "iota client call --package ${this.config.packageId} --module ${moduleName} --function mint --args ${args} --gas-budget 500000000"`;

        try {
            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractTransactionDigest(output);
            console.log(`✅ Minted ${this.config.amount} tokens to ${this.config.recipient}`);
            console.log(`   Digest: ${txDigest}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const txDigest = this.extractTransactionDigest(output);
            if (txDigest) {
                console.log(`✅ Minted ${this.config.amount} tokens to ${this.config.recipient}`);
                console.log(`   Digest: ${txDigest}`);
            } else {
                console.log(`❌ Mint failed: ${output.substring(0, 500)}`);
                process.exit(1);
            }
        }
    }

    private extractTransactionDigest(output: string): string | null {
        const patterns = [
            /Transaction Digest:\s*([a-zA-Z0-9]+)/i,
            /digest:\s*([a-zA-Z0-9]+)/i,
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

    private async burn(): Promise<void> {
        if (!this.config.amount) {
            console.log('ERROR: --amount required for burn');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        const moduleName = `${this.config.variant}_cmtat`;
        const args = `0x${'00'.repeat(32)} ${this.config.amount}`;
        
        const command = `bash -l -c "iota client call --package ${this.config.packageId} --module ${moduleName} --function burn --args ${args} --gas-budget 500000000"`;

        try {
            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractTransactionDigest(output);
            console.log(`✅ Burned ${this.config.amount} tokens`);
            console.log(`   Digest: ${txDigest}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const txDigest = this.extractTransactionDigest(output);
            if (txDigest) {
                console.log(`✅ Burned ${this.config.amount} tokens`);
                console.log(`   Digest: ${txDigest}`);
            } else {
                console.log(`❌ Burn failed: ${output.substring(0, 500)}`);
                process.exit(1);
            }
        }
    }

    private async transfer(): Promise<void> {
        if (!this.config.amount || !this.config.recipient) {
            console.log('ERROR: --amount and --recipient required for transfer');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        const command = `bash -l -c "iota client transfer-iota --to ${this.config.recipient} --amount ${this.config.amount} --gas-budget 50000000"`;

        try {
            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractTransactionDigest(output);
            console.log(`✅ Transferred ${this.config.amount} IOTA to ${this.config.recipient}`);
            console.log(`   Digest: ${txDigest}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const txDigest = this.extractTransactionDigest(output);
            if (txDigest) {
                console.log(`✅ Transferred ${this.config.amount} IOTA to ${this.config.recipient}`);
                console.log(`   Digest: ${txDigest}`);
            } else {
                console.log(`❌ Transfer failed: ${output.substring(0, 500)}`);
                process.exit(1);
            }
        }
    }

    private async pause(): Promise<void> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        const moduleName = `${this.config.variant}_cmtat`;
        const command = `bash -l -c "iota client call --package ${this.config.packageId} --module ${moduleName} --function pause --gas-budget 500000000"`;

        try {
            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractTransactionDigest(output);
            console.log('✅ Token transfers paused');
            console.log(`   Digest: ${txDigest}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const txDigest = this.extractTransactionDigest(output);
            if (txDigest) {
                console.log('✅ Token transfers paused');
                console.log(`   Digest: ${txDigest}`);
            } else {
                console.log(`❌ Pause failed: ${output.substring(0, 500)}`);
                process.exit(1);
            }
        }
    }

    private async unpause(): Promise<void> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        const moduleName = `${this.config.variant}_cmtat`;
        const command = `bash -l -c "iota client call --package ${this.config.packageId} --module ${moduleName} --function unpause --gas-budget 500000000"`;

        try {
            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractTransactionDigest(output);
            console.log('✅ Token transfers unpaused');
            console.log(`   Digest: ${txDigest}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const txDigest = this.extractTransactionDigest(output);
            if (txDigest) {
                console.log('✅ Token transfers unpaused');
                console.log(`   Digest: ${txDigest}`);
            } else {
                console.log(`❌ Unpause failed: ${output.substring(0, 500)}`);
                process.exit(1);
            }
        }
    }

    private async freeze(): Promise<void> {
        if (!this.config.address) {
            console.log('ERROR: --address required for freeze');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        const moduleName = `${this.config.variant}_cmtat`;
        const command = `bash -l -c "iota client call --package ${this.config.packageId} --module ${moduleName} --function freeze --args ${this.config.address} --gas-budget 500000000"`;

        try {
            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractTransactionDigest(output);
            console.log(`✅ Froze address ${this.config.address}`);
            console.log(`   Digest: ${txDigest}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const txDigest = this.extractTransactionDigest(output);
            if (txDigest) {
                console.log(`✅ Froze address ${this.config.address}`);
                console.log(`   Digest: ${txDigest}`);
            } else {
                console.log(`❌ Freeze failed: ${output.substring(0, 500)}`);
                process.exit(1);
            }
        }
    }

    private async unfreeze(): Promise<void> {
        if (!this.config.address) {
            console.log('ERROR: --address required for unfreeze');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        const moduleName = `${this.config.variant}_cmtat`;
        const command = `bash -l -c "iota client call --package ${this.config.packageId} --module ${moduleName} --function unfreeze --args ${this.config.address} --gas-budget 500000000"`;

        try {
            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractTransactionDigest(output);
            console.log(`✅ Unfroze address ${this.config.address}`);
            console.log(`   Digest: ${txDigest}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const txDigest = this.extractTransactionDigest(output);
            if (txDigest) {
                console.log(`✅ Unfroze address ${this.config.address}`);
                console.log(`   Digest: ${txDigest}`);
            } else {
                console.log(`❌ Unfreeze failed: ${output.substring(0, 500)}`);
                process.exit(1);
            }
        }
    }

    private async grantRole(): Promise<void> {
        if (!this.config.address || !this.config.role) {
            console.log('ERROR: --address and --role required for grant_role');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        const moduleName = `${this.config.variant}_cmtat`;
        const roleMap: Record<string, string> = {
            admin: 'DEFAULT_ADMIN_ROLE',
            minter: 'MINTER_ROLE',
            pauser: 'PAUSER_ROLE',
            enforcer: 'ENFORCER_ROLE',
        };
        const roleName = roleMap[this.config.role.toLowerCase()] || this.config.role.toUpperCase();
        
        const command = `bash -l -c "iota client call --package ${this.config.packageId} --module ${moduleName} --function grant_role --args ${this.config.address} ${roleName} --gas-budget 500000000"`;

        try {
            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractTransactionDigest(output);
            console.log(`✅ Granted ${this.config.role} to ${this.config.address}`);
            console.log(`   Digest: ${txDigest}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const txDigest = this.extractTransactionDigest(output);
            if (txDigest) {
                console.log(`✅ Granted ${this.config.role} to ${this.config.address}`);
                console.log(`   Digest: ${txDigest}`);
            } else {
                console.log(`❌ Grant role failed: ${output.substring(0, 500)}`);
                process.exit(1);
            }
        }
    }

    private async revokeRole(): Promise<void> {
        if (!this.config.address || !this.config.role) {
            console.log('ERROR: --address and --role required for revoke_role');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        const moduleName = `${this.config.variant}_cmtat`;
        const roleMap: Record<string, string> = {
            admin: 'DEFAULT_ADMIN_ROLE',
            minter: 'MINTER_ROLE',
            pauser: 'PAUSER_ROLE',
            enforcer: 'ENFORCER_ROLE',
        };
        const roleName = roleMap[this.config.role.toLowerCase()] || this.config.role.toUpperCase();
        
        const command = `bash -l -c "iota client call --package ${this.config.packageId} --module ${moduleName} --function revoke_role --args ${this.config.address} ${roleName} --gas-budget 500000000"`;

        try {
            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractTransactionDigest(output);
            console.log(`✅ Revoked ${this.config.role} from ${this.config.address}`);
            console.log(`   Digest: ${txDigest}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const txDigest = this.extractTransactionDigest(output);
            if (txDigest) {
                console.log(`✅ Revoked ${this.config.role} from ${this.config.address}`);
                console.log(`   Digest: ${txDigest}`);
            } else {
                console.log(`❌ Revoke role failed: ${output.substring(0, 500)}`);
                process.exit(1);
            }
        }
    }

    private async getBalance(): Promise<void> {
        const address = this.config.address || this.senderAddress;
        
        const balance = await this.getBalanceValue(address);
        
        console.log(`Balance for ${address}:`);
        console.log(`   Total: ${balance} mist`);
    }

    private async getBalanceValue(address: string): Promise<number> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        try {
            const output = execSync(`bash -l -c "iota client balance ${address}"`, execOptions).toString();
            const match = output.match(/(\d+)\s*mist/);
            if (match) {
                return parseInt(match[1], 10);
            }
            const plainMatch = output.match(/Total: (\d+)/);
            if (plainMatch) {
                return parseInt(plainMatch[1], 10);
            }
            return 0;
        } catch (error) {
            return 0;
        }
    }

    private async getTokenInfo(): Promise<void> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        
        try {
            console.log('Token Info:');
            console.log(`   Package ID: ${this.config.packageId}`);
            console.log(`   Variant: ${this.config.variant}`);
            
            const output = execSync(`bash -l -c "iota client objects ${this.config.packageId}"`, execOptions).toString();
            
            if (output.includes('TreasuryCap')) {
                const match = output.match(/TreasuryCap<([^>]+)>/);
                if (match) {
                    console.log(`   Coin Type: ${match[1]}`);
                }
            }
            
            if (output.includes('AdminCap')) {
                console.log(`   Status: Admin capabilities present`);
            }
            
            console.log(`   Use "iota client objects ${this.senderAddress}" to see owned coins`);
            
        } catch (error) {
            console.log('Error fetching token info:', error);
        }
    }
}

async function main() {
    const args = process.argv.slice(2);
    const config: InteractConfig = { ...defaultConfig };

    for (let i = 0; i < args.length; i++) {
        switch (args[i]) {
            case '--network':
                config.network = args[++i] as any;
                break;
            case '--private-key':
                config.privateKey = args[++i];
                break;
            case '--package-id':
                config.packageId = args[++i];
                break;
            case '--variant':
                config.variant = args[++i] as any;
                break;
            case '--action':
                config.action = args[++i];
                break;
            case '--amount':
                config.amount = parseInt(args[++i]);
                break;
            case '--recipient':
                config.recipient = args[++i];
                break;
            case '--address':
                config.address = args[++i];
                break;
            case '--role':
                config.role = args[++i];
                break;
            case '--help':
                printHelp();
                process.exit(0);
        }
    }

    if (!config.action) {
        console.log('ERROR: --action is required');
        printHelp();
        process.exit(1);
    }

    if (!config.packageId) {
        console.log('ERROR: --package-id is required');
        printHelp();
        process.exit(1);
    }

    const interactor = new TokenInteractor(config);
    await interactor.run();
}

function printHelp() {
    console.log(`
Move CMTAT Token Interaction

Usage:
  /usr/bin/node dist/interact.js [options]

Options:
  --package-id <id>    Package ID (required)
  --action <action>   Action to perform (required)
  --network <net>     Network (mainnet|testnet|devnet|localnet)
  --variant <var>     Variant (light|allowlist|debt|standard)
  --amount <n>        Amount for mint/burn/transfer
  --recipient <addr>  Recipient address
  --address <addr>    Address for freeze/role operations
  --role <role>       Role for grant/revoke (admin|minter|pauser|enforcer)
  --help              Show this help

Note: Uses CLI's active address automatically. No private key needed.

Actions:
  mint          Mint new tokens (requires --amount, --recipient)
  burn          Burn tokens (requires --amount)
  transfer      Transfer tokens (requires --amount, --recipient)
  pause         Pause token transfers
  unpause       Unpause token transfers
  freeze        Freeze address (requires --address)
  unfreeze      Unfreeze address (requires --address)
  grant_role    Grant role (requires --address, --role)
  revoke_role   Revoke role (requires --address, --role)
  balance       Get token balance (uses --address or default signer)
  info          Get token info

Examples:
  /usr/bin/node dist/interact.js --package-id 0x123... --action mint --amount 1000 --recipient 0x456...
  /usr/bin/node dist/interact.js --package-id 0x123... --action balance --address 0x456...
  /usr/bin/node dist/interact.js --package-id 0x123... --action pause
  /usr/bin/node dist/interact.js --package-id 0x123... --action freeze --address 0x456...
    `);
}

if (require.main === module) {
    main().catch(console.error);
}

export { TokenInteractor, InteractConfig };
