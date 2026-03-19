interface InteractConfig {
    network: 'mainnet' | 'testnet' | 'devnet' | 'localnet';
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
    private cliPath: string;

    constructor(config: InteractConfig) {
        const path = require('path');
        const fs = require('fs');
        const projectRoot = process.cwd();
        const localCli = path.join(projectRoot, 'iota');
        const cliExists = fs.existsSync(localCli);
        this.cliPath = cliExists ? localCli : 'iota';
        this.useWindowsGitBash = process.env.SHELL?.startsWith('C:') || false;
        if (this.useWindowsGitBash && this.cliPath.startsWith('/mnt/')) {
            this.cliPath = this.toWinPath(this.cliPath);
        } else if (!this.useWindowsGitBash && this.cliPath.startsWith('C:')) {
            this.cliPath = this.toWSLPath(this.cliPath);
        }
        
        this.config = config;
        this.switchNetwork(config.network);
        this.senderAddress = this.getCliActiveAddress();
        console.log(`📍 Signer Address (from CLI): ${this.senderAddress}`);
    }

    private useWindowsGitBash: boolean = false;

    private toWSLPath(winPath: string): string {
        return winPath.replace(/^C:/, '/mnt/c').replace(/\\/g, '/');
    }

    private toWinPath(wslPath: string): string {
        return wslPath.replace(/^\/mnt\/c/, 'C:').replace(/\//g, '\\');
    }

    private getIotaCmd(): string {
        if (this.useWindowsGitBash && this.cliPath.startsWith('C:')) {
            return '"' + this.cliPath + '"';
        }
        return this.cliPath;
    }

    private getBashCmd(): string {
        return '/usr/bin/bash';
    }

    private switchNetwork(network: string): void {
        if (network === 'localnet' || network === 'mainnet') {
            return;
        }
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        try {
            execSync(`${this.getBashCmd()} -c "${this.getIotaCmd()} client switch --env ${network}"`, execOptions);
        } catch (error) {
            // Ignore if already on the correct network
        }
    }

    private getCliActiveAddress(): string {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        try {
            const output = execSync(`${this.getBashCmd()} -c "${this.getIotaCmd()} client active-address"`, execOptions).toString().trim();
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
            const output = execSync(`${this.getBashCmd()} -c "${this.getIotaCmd()} client balance ${address}"`, execOptions).toString();
            const match = output.match(/(\d+)\s*mist/);
            if (match) return parseInt(match[1], 10);
            const plainMatch = output.match(/Total: (\d+)/);
            if (plainMatch) return parseInt(plainMatch[1], 10);
            return 0;
        } catch (error) {
            return 0;
        }
    }

    private async requestFaucet(address: string): Promise<void> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        try {
            execSync(`${this.getBashCmd()} -c "${this.getIotaCmd()} client switch --env testnet"`, execOptions);
            const output = execSync(`${this.getBashCmd()} -c "${this.getIotaCmd()} client faucet --address ${address}"`, execOptions).toString();
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

        console.log('🔍 Discovering token objects...');
        const objects = await this.discoverTokenObjects();

        if (!objects.treasuryCap) {
            console.log('ERROR: TreasuryCap not found. Make sure you are the deployer/admin of this contract.');
            process.exit(1);
        }

        if (!objects.registry) {
            console.log('ERROR: Registry not found.');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const moduleName = `${this.config.variant}_cmtat`;
        const denyListOrCap = objects.denyList || objects.denyCap || '0x0';
        const args = `${objects.treasuryCap} ${objects.registry} ${denyListOrCap} ${this.config.recipient} ${this.config.amount}`;
        const command = `${this.getBashCmd()} -c "${this.getIotaCmd()} client call --package ${this.config.packageId} --module ${moduleName} --function mint_and_transfer --args ${args} --gas-budget 500000000"`;

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

    private async discoverTokenObjects(): Promise<{treasuryCap?: string, registry?: string, denyList?: string, denyCap?: string}> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const result: {treasuryCap?: string, registry?: string, denyList?: string, denyCap?: string} = {};

        try {
            const output = execSync(`${this.getBashCmd()} -c "${this.getIotaCmd()} client objects ${this.senderAddress} --json"`, execOptions).toString();
            let objects: any[];
            try {
                objects = JSON.parse(output);
            } catch {
                return this.discoverTokenObjectsRegex(output);
            }

            const packageId = this.config.packageId;
            const coinTypes: Record<string, string> = {
                light: 'LIGHT_CMTAT',
                allowlist: 'ALLOWLIST_CMTAT',
                debt: 'DEBT_CMTAT',
                standard: 'STANDARD_CMTAT'
            };
            const coinType = coinTypes[this.config.variant] || this.config.variant.toUpperCase();

            for (const obj of objects || []) {
                const type = obj.data?.type || '';
                if (type.includes('TreasuryCap') && type.includes(packageId) && type.includes(coinType)) {
                    result.treasuryCap = obj.data.objectId;
                    console.log(`   Found TreasuryCap: ${result.treasuryCap}`);
                }
                if (type.includes('DenyCapV1') && type.includes(packageId) && type.includes(coinType)) {
                    result.denyCap = obj.data.objectId;
                    console.log(`   Found DenyCap: ${result.denyCap}`);
                }
                if (type.includes('DenyList') && type.includes(packageId)) {
                    result.denyList = obj.data.objectId;
                    console.log(`   Found DenyList: ${result.denyList}`);
                }
                const registryPatterns = ['Registry', 'CMTATState', 'LightCMTATState', 'StandardCMTATState', 'DebtCMTATState', 'AllowlistCMTATState'];
                if (!result.registry && registryPatterns.some(p => type.includes(p)) && type.includes(packageId)) {
                    result.registry = obj.data.objectId;
                    console.log(`   Found Registry: ${result.registry}`);
                }
            }
        } catch (error) {
            console.log('   Warning: Could not discover all objects via JSON');
        }

        return result;
    }

    private async discoverTokenObjectsRegex(output: string): Promise<{treasuryCap?: string, registry?: string, denyList?: string, denyCap?: string}> {
        const result: {treasuryCap?: string, registry?: string, denyList?: string, denyCap?: string} = {};
        const packageId = this.config.packageId;
        const coinTypes: Record<string, string> = {
            light: 'LIGHT_CMTAT',
            allowlist: 'ALLOWLIST_CMTAT',
            debt: 'DEBT_CMTAT',
            standard: 'STANDARD_CMTAT'
        };
        const coinType = coinTypes[this.config.variant] || this.config.variant.toUpperCase();

        const treasuryCapRe = new RegExp(`"objectId":\\s*"([^"]+)"[^}]*TreasuryCap[^}]*${coinType}`, 'g');
        let match;
        while ((match = treasuryCapRe.exec(output)) !== null && !result.treasuryCap) {
            if (match[0].includes(packageId)) {
                result.treasuryCap = match[1];
                console.log(`   Found TreasuryCap: ${result.treasuryCap}`);
            }
        }

        const denyCapRe = new RegExp(`"objectId":\\s*"([^"]+)"[^}]*DenyCapV1[^}]*${coinType}`, 'g');
        while ((match = denyCapRe.exec(output)) !== null && !result.denyCap) {
            if (match[0].includes(packageId)) {
                result.denyCap = match[1];
                console.log(`   Found DenyCap: ${result.denyCap}`);
            }
        }

        const denyListRe = /"objectId":\s*"([^"]+)"[^}]*DenyList/g;
        while ((match = denyListRe.exec(output)) !== null && !result.denyList) {
            result.denyList = match[1];
            console.log(`   Found DenyList: ${result.denyList}`);
        }

        const registryRe = /"objectId":\s*"([^"]+)"[^}]*(Registry|CMTATState)/g;
        while ((match = registryRe.exec(output)) !== null && !result.registry) {
            if (match[0].includes(packageId)) {
                result.registry = match[1];
                console.log(`   Found Registry: ${result.registry}`);
            }
        }

        return result;
    }

    private extractTransactionDigest(output: string): string | null {
        const patterns = [
            /Transaction Digest:\s*([a-zA-Z0-9]+)/i,
            /digest:\s*([a-zA-Z0-9]+)/i,
            /Digest:\s*([a-zA-Z0-9]+)/i,
        ];
        for (const pattern of patterns) {
            const match = output.match(pattern);
            if (match) return match[1];
        }
        return null;
    }

    private async burn(): Promise<void> {
        if (!this.config.amount) {
            console.log('ERROR: --amount required for burn');
            process.exit(1);
        }

        const objects = await this.discoverTokenObjects();
        if (!objects.treasuryCap) {
            console.log('ERROR: TreasuryCap not found.');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const moduleName = `${this.config.variant}_cmtat`;
        const args = `${objects.treasuryCap} ${this.config.amount}`;
        const command = `${this.getBashCmd()} -c "${this.getIotaCmd()} client call --package ${this.config.packageId} --module ${moduleName} --function burn --args ${args} --gas-budget 500000000"`;

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
        const command = `${this.getBashCmd()} -c "${this.getIotaCmd()} client transfer-iota --to ${this.config.recipient} --amount ${this.config.amount} --gas-budget 50000000"`;

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
        const command = `${this.getBashCmd()} -c "${this.getIotaCmd()} client call --package ${this.config.packageId} --module ${moduleName} --function pause --gas-budget 500000000"`;

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
        const command = `${this.getBashCmd()} -c "${this.getIotaCmd()} client call --package ${this.config.packageId} --module ${moduleName} --function unpause --gas-budget 500000000"`;

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
        const command = `${this.getBashCmd()} -c "${this.getIotaCmd()} client call --package ${this.config.packageId} --module ${moduleName} --function freeze --args ${this.config.address} --gas-budget 500000000"`;

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
        const command = `${this.getBashCmd()} -c "${this.getIotaCmd()} client call --package ${this.config.packageId} --module ${moduleName} --function unfreeze --args ${this.config.address} --gas-budget 500000000"`;

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
        const command = `${this.getBashCmd()} -c "${this.getIotaCmd()} client call --package ${this.config.packageId} --module ${moduleName} --function grant_role --args ${this.config.address} ${roleName} --gas-budget 500000000"`;

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
        const command = `${this.getBashCmd()} -c "${this.getIotaCmd()} client call --package ${this.config.packageId} --module ${moduleName} --function revoke_role --args ${this.config.address} ${roleName} --gas-budget 500000000"`;

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
        const balance = await this.getWalletBalance(address);
        console.log(`Balance for ${address}:`);
        console.log(`   Total: ${balance} mist`);
    }

    private async getTokenInfo(): Promise<void> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();

        console.log('Token Info:');
        console.log(`   Package ID: ${this.config.packageId}`);
        console.log(`   Variant: ${this.config.variant}`);

        try {
            const output = execSync(`${this.getBashCmd()} -c "${this.getIotaCmd()} client objects ${this.config.packageId}"`, execOptions).toString();
            if (output.includes('TreasuryCap')) {
                const match = output.match(/TreasuryCap<([^>]+)>/);
                if (match) console.log(`   Coin Type: ${match[1]}`);
            }
            if (output.includes('AdminCap')) {
                console.log(`   Status: Admin capabilities present`);
            }
            console.log(`   Use "iota client objects ${this.senderAddress}" to see owned coins`);
        } catch (error) {
            console.log('Error fetching token info');
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
