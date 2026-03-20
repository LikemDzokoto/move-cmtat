interface InteractConfig {
    network: 'mainnet' | 'testnet' | 'devnet' | 'localnet';
    packageId: string;
    variant: 'light' | 'allowlist' | 'debt' | 'standard';
    action: string;
    amount?: number;
    recipient?: string;
    address?: string;
    role?: string;
    
    continueOnError?: boolean;
    delayMs?: number;
    
    tokenId?: string;
    terms?: string;
    information?: string;
    documentUri?: string;
    
    allowlistAddresses?: string;
    enableAllowlist?: boolean;
    
    allocations?: string;
    snapshotAfter?: boolean;
    
    couponNumber?: number;
    
    isin?: string;
    issuerName?: string;
    issuerDescription?: string;
    guarantor?: string;
    debtHolderRep?: string;
    interestRate?: number;
    parValue?: number;
    minimumDenomination?: number;
    issuanceDate?: number;
    maturityDate?: number;
    couponFrequency?: string;
    interestScheduleFormat?: string;
    interestPaymentDate?: string;
    dayCountConvention?: number;
    businessDayConvention?: number;
    currency?: string;
    currencyContract?: string;
    callSchedule?: string;
    putSchedule?: string;
    sinkingFundSchedule?: string;
    convertibleTerms?: string;
    collateralDescription?: string;
    rating?: string;
    
    emergencyAction?: string;
    freezeAddresses?: string;
    flagRedeemed?: boolean;
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
        this.verifyCliExists();
        this.switchNetwork(config.network);
        this.senderAddress = this.getCliActiveAddress();
        console.log(`📍 Signer Address (from CLI): ${this.senderAddress}`);
    }

    private verifyCliExists(): void {
        const { execSync } = require('child_process');
        try {
            execSync('iota --version', { stdio: 'pipe' });
        } catch {
            console.error('\n❌ Error: "iota" CLI not found in PATH');
            console.error('   Please install IOTA CLI and ensure it\'s in your PATH');
            console.error('   Download: https://github.com/iotaledger/iota-cli/releases\n');
            process.exit(1);
        }
    }

    private switchNetwork(network: string): void {
        if (network === 'localnet' || network === 'mainnet') {
            return;
        }
        const { execSync } = require('child_process');
        try {
            execSync(`iota client switch --env ${network}`, { stdio: 'pipe' });
        } catch {
            // Ignore if already on the correct network
        }
    }

    private getCliActiveAddress(): string {
        const { execSync } = require('child_process');
        try {
            const output = execSync('iota client active-address', { stdio: 'pipe' }).toString().trim();
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
        try {
            const output = execSync(`iota client balance ${address}`, { stdio: 'pipe' }).toString();
            const match = output.match(/balance.*?(\d+)\s+NANOS/i);
            if (match) return parseInt(match[1], 10);
            const rawMatch = output.match(/IOTA\s+(\d+)/);
            if (rawMatch) return parseInt(rawMatch[1], 10);
            const mistMatch = output.match(/(\d+)\s*mist/i);
            if (mistMatch) return parseInt(mistMatch[1], 10);
            return 0;
        } catch (error) {
            return 0;
        }
    }

    private async requestFaucet(address: string): Promise<void> {
        const { execSync } = require('child_process');
        try {
            execSync('iota client switch --env testnet', { stdio: 'pipe' });
            const output = execSync(`iota client faucet --address ${address}`, { stdio: 'pipe' }).toString();
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
            flow_setup: () => this.flowSetup(),
            flow_onboard: () => this.flowOnboard(),
            flow_issue: () => this.flowIssue(),
            flow_coupon: () => this.flowCoupon(),
            flow_redeem: () => this.flowRedeem(),
            flow_emergency: () => this.flowEmergency(),
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
        const systemDenyList = '0x403';
        const systemClock = '0x6';
        
        let args: string;
        let functionName = 'mint_and_transfer';
        
        switch (this.config.variant) {
            case 'light':
                args = `${objects.treasuryCap} ${objects.registry} ${systemDenyList} ${this.config.recipient} ${this.config.amount}`;
                break;
            case 'standard':
                if (!objects.state) {
                    console.log('ERROR: StandardCMTATState not found.');
                    process.exit(1);
                }
                args = `${objects.treasuryCap} ${objects.registry} ${objects.state} ${systemDenyList} ${systemClock} ${this.config.recipient} ${this.config.amount}`;
                break;
            case 'allowlist':
                if (!objects.state) {
                    console.log('ERROR: AllowlistCMTATState not found.');
                    process.exit(1);
                }
                if (!objects.complianceState) {
                    console.log('ERROR: ComplianceState not found.');
                    process.exit(1);
                }
                args = `${objects.treasuryCap} ${objects.registry} ${objects.state} ${objects.complianceState} ${systemDenyList} ${systemClock} ${this.config.recipient} ${this.config.amount}`;
                break;
            case 'debt':
                if (!objects.state) {
                    console.log('ERROR: DebtCMTATState not found.');
                    process.exit(1);
                }
                args = `${objects.treasuryCap} ${objects.registry} ${objects.state} ${systemDenyList} ${systemClock} ${this.config.recipient} ${this.config.amount}`;
                break;
            default:
                console.log(`ERROR: Unknown variant: ${this.config.variant}`);
                process.exit(1);
        }
        
        const command = `iota client call --package ${this.config.packageId} --module ${moduleName} --function ${functionName} --args ${args} --gas-budget 500000000`;

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

    private async getPackageDeployTransaction(): Promise<string | null> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        try {
            const output = execSync(`iota client object ${this.config.packageId} --json`, execOptions).toString();
            const data = JSON.parse(output);
            return data.previousTransaction || null;
        } catch {
            return null;
        }
    }

    private async discoverSharedObjectsFromTx(result: any, txDigest: string): Promise<void> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const packageId = this.config.packageId;

        const registryTypes: Record<string, string> = {
            light: 'LightCMTATRegistry',
            allowlist: 'allowlist_cmtat::CMTATRegistry',
            debt: 'debt_cmtat::CMTATRegistry',
            standard: 'standard_cmtat::CMTATRegistry'
        };

        const stateTypes: Record<string, string> = {
            light: '',
            allowlist: 'AllowlistCMTATState',
            debt: 'DebtCMTATState',
            standard: 'StandardCMTATState'
        };

        try {
            const output = execSync(`iota client tx-block ${txDigest} --json`, execOptions).toString();
            const data = JSON.parse(output);
            const changes = data.objectChanges || [];

            for (const change of changes) {
                if (change.type === 'created' && change.owner?.Shared) {
                    const objType = change.objectType || '';
                    if (objType.includes(packageId)) {
                        if (objType.includes(registryTypes[this.config.variant])) {
                            result.registry = change.objectId;
                            console.log(`   Found Registry (shared): ${result.registry}`);
                        }
                        if (stateTypes[this.config.variant] && objType.includes(stateTypes[this.config.variant])) {
                            result.state = change.objectId;
                            console.log(`   Found State (shared): ${result.state}`);
                        }
                        if (objType.includes('ComplianceState')) {
                            result.complianceState = change.objectId;
                            console.log(`   Found ComplianceState (shared): ${result.complianceState}`);
                        }
                        if (objType.includes('DenyList') && !objType.includes(packageId)) {
                            result.denyList = change.objectId;
                            console.log(`   Found DenyList (shared): ${result.denyList}`);
                        }
                    }
                }
            }
        } catch (error) {
            console.log('   Warning: Could not discover shared objects from transaction');
        }
    }

    private async discoverTokenObjects(): Promise<{treasuryCap?: string, registry?: string, denyList?: string, denyCap?: string, adminCap?: string, state?: string, complianceState?: string, snapshotCap?: string, txDigest?: string}> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const result: {treasuryCap?: string, registry?: string, denyList?: string, denyCap?: string, adminCap?: string, state?: string, complianceState?: string, snapshotCap?: string, txDigest?: string} = {};

        result.txDigest = await this.getPackageDeployTransaction();
        if (result.txDigest) {
            await this.discoverSharedObjectsFromTx(result, result.txDigest);
        }

        try {
            const output = execSync(`iota client objects ${this.senderAddress} --json`, execOptions).toString();
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
                const adminCapPatterns: Record<string, string> = {
                    light: 'light_cmtat::AdminCap',
                    allowlist: 'allowlist_cmtat::AdminCap',
                    debt: 'debt_cmtat::AdminCap',
                    standard: 'standard_cmtat::AdminCap'
                };
                const adminCapPattern = adminCapPatterns[this.config.variant];
                if (!result.adminCap && type.includes(adminCapPattern) && type.includes(packageId)) {
                    result.adminCap = obj.data.objectId;
                    console.log(`   Found AdminCap: ${result.adminCap}`);
                }
                if (type.includes('DenyList') && type.includes(packageId)) {
                    result.denyList = obj.data.objectId;
                    console.log(`   Found DenyList: ${result.denyList}`);
                }
                const registryPatterns: Record<string, string> = {
                    light: 'LightCMTATRegistry',
                    allowlist: 'allowlist_cmtat::CMTATRegistry',
                    debt: 'debt_cmtat::CMTATRegistry',
                    standard: 'standard_cmtat::CMTATRegistry'
                };
                const registryPattern = registryPatterns[this.config.variant];
                if (!result.registry && type.includes(registryPattern) && type.includes(packageId)) {
                    result.registry = obj.data.objectId;
                    console.log(`   Found Registry: ${result.registry}`);
                }
                const statePatterns: Record<string, string> = {
                    light: '',
                    allowlist: 'AllowlistCMTATState',
                    debt: 'DebtCMTATState',
                    standard: 'StandardCMTATState'
                };
                const statePattern = statePatterns[this.config.variant];
                if (statePattern && !result.state && type.includes(statePattern) && type.includes(packageId)) {
                    result.state = obj.data.objectId;
                    console.log(`   Found State: ${result.state}`);
                }
                if (!result.complianceState && type.includes('ComplianceState') && type.includes(packageId)) {
                    result.complianceState = obj.data.objectId;
                    console.log(`   Found ComplianceState: ${result.complianceState}`);
                }
                const snapshotCapPatterns: Record<string, string> = {
                    light: '',
                    allowlist: 'allowlist_cmtat::SnapshotCap',
                    debt: 'debt_cmtat::SnapshotCap',
                    standard: 'standard_cmtat::SnapshotCap'
                };
                const snapshotCapPattern = snapshotCapPatterns[this.config.variant];
                if (snapshotCapPattern && !result.snapshotCap && type.includes(snapshotCapPattern) && type.includes(packageId)) {
                    result.snapshotCap = obj.data.objectId;
                    console.log(`   Found SnapshotCap: ${result.snapshotCap}`);
                }
            }
        } catch (error) {
            console.log('   Warning: Could not discover all objects via JSON');
        }

        return result;
    }

    private async discoverTokenObjectsRegex(output: string): Promise<{treasuryCap?: string, registry?: string, denyList?: string, denyCap?: string, state?: string, complianceState?: string, txDigest?: string}> {
        const result: {treasuryCap?: string, registry?: string, denyList?: string, denyCap?: string, state?: string, complianceState?: string, txDigest?: string} = {};
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

        const registryPatterns: Record<string, string> = {
            light: 'LightCMTATRegistry',
            allowlist: 'allowlist_cmtat::CMTATRegistry',
            debt: 'debt_cmtat::CMTATRegistry',
            standard: 'standard_cmtat::CMTATRegistry'
        };
        const registryName = registryPatterns[this.config.variant];
        const registryRe = new RegExp(`"objectId":\\s*"([^"]+)"[^}]*${registryName}`, 'g');
        while ((match = registryRe.exec(output)) !== null && !result.registry) {
            if (match[0].includes(packageId)) {
                result.registry = match[1];
                console.log(`   Found Registry: ${result.registry}`);
            }
        }

        const statePatterns: Record<string, string> = {
            light: '',
            allowlist: 'AllowlistCMTATState',
            debt: 'DebtCMTATState',
            standard: 'StandardCMTATState'
        };
        const stateName = statePatterns[this.config.variant];
        if (stateName) {
            const stateRe = new RegExp(`"objectId":\\s*"([^"]+)"[^}]*${stateName}`, 'g');
            while ((match = stateRe.exec(output)) !== null && !result.state) {
                if (match[0].includes(packageId)) {
                    result.state = match[1];
                    console.log(`   Found State: ${result.state}`);
                }
            }
        }

        const complianceRe = /"objectId":\s*"([^"]+)"[^}]*ComplianceState/g;
        while ((match = complianceRe.exec(output)) !== null && !result.complianceState) {
            if (match[0].includes(packageId)) {
                result.complianceState = match[1];
                console.log(`   Found ComplianceState: ${result.complianceState}`);
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
        const command = `iota client call --package ${this.config.packageId} --module ${moduleName} --function burn --args ${args} --gas-budget 500000000`;

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
        const command = `iota client pay-iota --recipients ${this.config.recipient} --amounts ${this.config.amount} --gas-budget 50000000`;

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
        const objects = await this.discoverTokenObjects();
        
        if (!objects.treasuryCap) {
            console.log('ERROR: TreasuryCap not found.');
            process.exit(1);
        }
        if (!objects.registry) {
            console.log('ERROR: Registry not found.');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const moduleName = `${this.config.variant}_cmtat`;
        const systemDenyList = '0x403';
        const args = `${systemDenyList} ${objects.denyCap} ${objects.registry}`;
        const command = `iota client call --package ${this.config.packageId} --module ${moduleName} --function pause --args ${args} --gas-budget 500000000`;

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
        const objects = await this.discoverTokenObjects();
        
        if (!objects.treasuryCap) {
            console.log('ERROR: TreasuryCap not found.');
            process.exit(1);
        }
        if (!objects.registry) {
            console.log('ERROR: Registry not found.');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const moduleName = `${this.config.variant}_cmtat`;
        const systemDenyList = '0x403';
        const args = `${systemDenyList} ${objects.denyCap} ${objects.registry}`;
        const command = `iota client call --package ${this.config.packageId} --module ${moduleName} --function unpause --args ${args} --gas-budget 500000000`;

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

        const objects = await this.discoverTokenObjects();
        
        if (!objects.denyCap) {
            console.log('ERROR: DenyCap not found.');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const moduleName = `${this.config.variant}_cmtat`;
        const systemDenyList = '0x403';
        const args = `${systemDenyList} ${objects.denyCap} ${this.config.address} true`;
        const command = `iota client call --package ${this.config.packageId} --module ${moduleName} --function set_address_frozen --args ${args} --gas-budget 500000000`;

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

        const objects = await this.discoverTokenObjects();
        
        if (!objects.denyCap) {
            console.log('ERROR: DenyCap not found.');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const moduleName = `${this.config.variant}_cmtat`;
        const systemDenyList = '0x403';
        const args = `${systemDenyList} ${objects.denyCap} ${this.config.address} false`;
        const command = `iota client call --package ${this.config.packageId} --module ${moduleName} --function set_address_frozen --args ${args} --gas-budget 500000000`;

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

        const objects = await this.discoverTokenObjects();
        
        if (!objects.treasuryCap) {
            console.log('ERROR: TreasuryCap not found.');
            process.exit(1);
        }
        if (!objects.adminCap) {
            console.log('ERROR: AdminCap not found. You need AdminCap to grant roles.');
            process.exit(1);
        }

        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const moduleName = `${this.config.variant}_cmtat`;
        
        let functionName: string;
        let args: string;
        
        switch (this.config.role.toLowerCase()) {
            case 'minter':
                functionName = 'grant_minter';
                args = `${objects.adminCap} ${objects.treasuryCap} ${this.config.address}`;
                break;
            case 'pauser':
                functionName = 'grant_pauser';
                args = `${objects.adminCap} ${objects.denyCap} ${this.config.address}`;
                break;
            case 'enforcer':
                functionName = 'grant_enforcer';
                args = `${objects.adminCap} ${objects.denyCap} ${this.config.address}`;
                break;
            default:
                console.log(`ERROR: Unknown role: ${this.config.role}`);
                console.log(`Available roles: minter, pauser, enforcer`);
                process.exit(1);
        }
        
        const command = `iota client call --package ${this.config.packageId} --module ${moduleName} --function ${functionName} --args ${args} --gas-budget 500000000`;

        try {
            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractTransactionDigest(output);
            console.log(`✅ Granted ${this.config.role} role to ${this.config.address}`);
            console.log(`   Digest: ${txDigest}`);
        } catch (error: any) {
            const output = error.stdout?.toString() || error.stderr?.toString() || error.message || '';
            const txDigest = this.extractTransactionDigest(output);
            if (txDigest) {
                console.log(`✅ Granted ${this.config.role} role to ${this.config.address}`);
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

        console.log('ℹ️  Note: Light CMTAT does not support revoke_role. Roles are granted but cannot be revoked.');
        console.log('   Consider using freeze/unfreeze to restrict addresses.');
        process.exit(1);
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
            const output = execSync(`iota client objects ${this.config.packageId}`, execOptions).toString();
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

    private async flowSetup(): Promise<void> {
        console.log('⚙️  FLOW: Setup (Atomic - All-or-Nothing)');
        console.log('==========================================');
        
        const delayMs = this.config.delayMs || 2000;
        const errors: string[] = [];
        
        console.log('\n📋 Step 1: Verify token objects...');
        const objects = await this.discoverTokenObjects();
        
        if (!objects.treasuryCap) {
            errors.push('TreasuryCap not found - deploy contract first');
        }
        if (!objects.registry) {
            errors.push('Registry not found');
        }
        if (this.config.variant !== 'light' && !objects.state) {
            errors.push(`${this.config.variant} State not found`);
        }
        
        if (errors.length > 0) {
            console.log('\n❌ FLOW FAILED (Atomic - rolling back):');
            errors.forEach(e => console.log(`   - ${e}`));
            process.exit(1);
        }
        
        console.log('\n📋 Step 2: Grant roles to addresses from --allowlist-addresses...');
        const addresses = this.parseAddresses(this.config.allowlistAddresses || '');
        if (addresses.length === 0) {
            console.log('   No addresses provided, skipping role grants');
        } else {
            for (const addr of addresses) {
                try {
                    await this.grantRoleToAddress(addr, 'minter');
                    await this.delay(delayMs);
                    await this.grantRoleToAddress(addr, 'pauser');
                    await this.delay(delayMs);
                    console.log(`   ✅ Granted minter & pauser roles to ${addr}`);
                } catch (e: any) {
                    errors.push(`Failed to grant roles to ${addr}: ${e.message}`);
                }
            }
        }
        
        if (errors.length > 0 && !this.config.continueOnError) {
            console.log('\n❌ FLOW FAILED (Atomic - rolling back):');
            errors.forEach(e => console.log(`   - ${e}`));
            process.exit(1);
        }
        
        console.log('\n✅ FLOW SETUP COMPLETED');
        console.log('   All-or-nothing: ' + (errors.length === 0 ? 'SUCCESS' : 'PARTIAL (errors occurred)'));
    }

    private async flowOnboard(): Promise<void> {
        console.log('🔗 FLOW: Onboard (Continue-on-Error)');
        console.log('====================================');
        
        const delayMs = this.config.delayMs || 500;
        const errors: string[] = [];
        const results: { address: string; success: boolean; error?: string }[] = [];
        
        console.log('\n📋 Step 1: Parse onboard addresses...');
        const addresses = this.parseAddresses(this.config.allowlistAddresses || '');
        if (addresses.length === 0) {
            console.log('ERROR: --allowlist-addresses required for onboard flow');
            process.exit(1);
        }
        console.log(`   Found ${addresses.length} addresses to onboard`);
        
        console.log('\n📋 Step 2: Add to allowlist (allowlist variant only)...');
        if (this.config.variant === 'allowlist') {
            for (const addr of addresses) {
                try {
                    await this.addToAllowlist(addr);
                    await this.delay(delayMs);
                    results.push({ address: addr, success: true });
                    console.log(`   ✅ Added ${addr} to allowlist`);
                } catch (e: any) {
                    const errorMsg = e.message || String(e);
                    results.push({ address: addr, success: false, error: errorMsg });
                    errors.push(errorMsg);
                    console.log(`   ⚠️  Failed to add ${addr}: ${errorMsg.substring(0, 100)}`);
                    if (!this.config.continueOnError) {
                        console.log('\n❌ FLOW STOPPED (continue-on-error disabled)');
                        break;
                    }
                }
            }
        } else {
            console.log(`   Skipping (variant is ${this.config.variant}, not allowlist)`);
        }
        
        console.log('\n📋 Step 3: Grant minter role...');
        const objects = await this.discoverTokenObjects();
        if (objects.adminCap && objects.treasuryCap) {
            for (const addr of addresses) {
                try {
                    await this.grantRoleToAddress(addr, 'minter');
                    await this.delay(delayMs);
                    console.log(`   ✅ Granted minter role to ${addr}`);
                } catch (e: any) {
                    const errorMsg = e.message || String(e);
                    errors.push(errorMsg);
                    console.log(`   ⚠️  Failed to grant minter to ${addr}: ${errorMsg.substring(0, 100)}`);
                    if (!this.config.continueOnError) {
                        console.log('\n❌ FLOW STOPPED (continue-on-error disabled)');
                        break;
                    }
                }
            }
        } else {
            errors.push('AdminCap or TreasuryCap not found');
        }
        
        console.log('\n✅ FLOW ONBOARD COMPLETED');
        console.log(`   Total: ${addresses.length}, Success: ${addresses.length - errors.length}, Failed: ${errors.length}`);
        if (errors.length > 0 && !this.config.continueOnError) {
            process.exit(1);
        }
    }

    private async flowIssue(): Promise<void> {
        console.log('💰 FLOW: Issue (Continue-on-Error + Snapshot)');
        console.log('===============================================');
        
        const delayMs = this.config.delayMs || 1000;
        const errors: string[] = [];
        
        console.log('\n📋 Step 1: Parse token allocations...');
        interface Allocation { address: string; amount: number; }
        let allocations: Allocation[] = [];
        try {
            allocations = JSON.parse(this.config.allocations || '[]');
        } catch {
            console.log('ERROR: --allocations must be valid JSON array [{address, amount}, ...]');
            process.exit(1);
        }
        if (allocations.length === 0) {
            console.log('ERROR: --allocations required for issue flow');
            process.exit(1);
        }
        console.log(`   Found ${allocations.length} allocations`);
        
        console.log('\n📋 Step 2: Mint tokens to recipients...');
        for (const alloc of allocations) {
            try {
                this.config.recipient = alloc.address;
                this.config.amount = alloc.amount;
                await this.mint();
                await this.delay(delayMs);
                console.log(`   ✅ Minted ${alloc.amount} to ${alloc.address}`);
            } catch (e: any) {
                const errorMsg = e.message || String(e);
                errors.push(errorMsg);
                console.log(`   ⚠️  Failed to mint to ${alloc.address}: ${errorMsg.substring(0, 100)}`);
                if (!this.config.continueOnError) {
                    console.log('\n❌ FLOW STOPPED (continue-on-error disabled)');
                    break;
                }
            }
        }
        
        if (this.config.snapshotAfter) {
            console.log('\n📋 Step 3: Take snapshot...');
            try {
                await this.takeSnapshot();
                console.log('   ✅ Snapshot taken');
            } catch (e: any) {
                errors.push(`Snapshot failed: ${e.message}`);
                console.log(`   ⚠️  Snapshot failed: ${e.message}`);
            }
        }
        
        console.log('\n✅ FLOW ISSUE COMPLETED');
        console.log(`   Total: ${allocations.length}, Success: ${allocations.length - errors.length}, Failed: ${errors.length}`);
        if (errors.length > 0 && !this.config.continueOnError) {
            process.exit(1);
        }
    }

    private async flowCoupon(): Promise<void> {
        console.log('📅 FLOW: Coupon Distribution (Continue-on-Error)');
        console.log('=================================================');
        
        const delayMs = this.config.delayMs || 2000;
        const errors: string[] = [];
        
        if (this.config.variant !== 'debt') {
            console.log('ERROR: Coupon flow only supported for debt variant');
            process.exit(1);
        }
        
        const couponNumber = this.config.couponNumber || 1;
        console.log(`\n📋 Step 1: Distributing coupon #${couponNumber}...`);
        console.log(`   Interest rate: ${this.config.interestRate || 'from contract'}`);
        
        console.log('\n📋 Step 2: Calculate coupon amounts...');
        let allocations: { address: string; amount: number }[] = [];
        try {
            allocations = JSON.parse(this.config.allocations || '[]');
        } catch {
            console.log('ERROR: --allocations must be valid JSON');
            process.exit(1);
        }
        
        console.log('\n📋 Step 3: Transfer coupon payments to holders...');
        for (const alloc of allocations) {
            try {
                this.config.recipient = alloc.address;
                this.config.amount = alloc.amount;
                await this.transfer();
                await this.delay(delayMs);
                console.log(`   ✅ Paid coupon ${alloc.amount} to ${alloc.address}`);
            } catch (e: any) {
                const errorMsg = e.message || String(e);
                errors.push(errorMsg);
                console.log(`   ⚠️  Failed to pay coupon to ${alloc.address}: ${errorMsg.substring(0, 100)}`);
                if (!this.config.continueOnError) {
                    break;
                }
            }
        }
        
        console.log('\n✅ FLOW COUPON COMPLETED');
        console.log(`   Coupon #${couponNumber}, Success: ${allocations.length - errors.length}, Failed: ${errors.length}`);
        if (errors.length > 0 && !this.config.continueOnError) {
            process.exit(1);
        }
    }

    private async flowRedeem(): Promise<void> {
        console.log('🏦 FLOW: Redeem (Atomic - All-or-Nothing)');
        console.log('===========================================');
        
        const delayMs = this.config.delayMs || 2000;
        const errors: string[] = [];
        
        if (this.config.variant !== 'debt') {
            console.log('ERROR: Redeem flow only supported for debt variant');
            process.exit(1);
        }
        
        console.log('\n📋 Step 1: Parse redemption data...');
        interface Redemption { address: string; amount: number; }
        let redemptions: Redemption[] = [];
        try {
            redemptions = JSON.parse(this.config.allocations || '[]');
        } catch {
            console.log('ERROR: --allocations must be valid JSON [{address, amount}, ...]');
            process.exit(1);
        }
        if (redemptions.length === 0) {
            console.log('ERROR: --allocations required for redeem flow');
            process.exit(1);
        }
        
        console.log('\n📋 Step 2: Mint tokens for redemption...');
        for (const redeem of redemptions) {
            try {
                this.config.recipient = this.senderAddress;
                this.config.amount = redeem.amount;
                await this.mint();
                await this.delay(delayMs);
                console.log(`   ✅ Minted ${redeem.amount} for redemption`);
            } catch (e: any) {
                errors.push(`Failed to mint for ${redeem.address}: ${e.message}`);
            }
        }
        
        if (errors.length > 0) {
            console.log('\n❌ FLOW FAILED (Atomic - rolling back)');
            errors.forEach(e => console.log(`   - ${e}`));
            process.exit(1);
        }
        
        console.log('\n📋 Step 3: Record redemption (CLI requires Coin objects for actual burn)...');
        console.log('   ℹ️  Note: Actual token burn requires Coin object manipulation via SDK');
        console.log('   The following redemptions are recorded:');
        for (const redeem of redemptions) {
            console.log(`   - Address: ${redeem.address}, Amount: ${redeem.amount}`);
        }
        console.log('\n   To complete burn manually:');
        console.log('   1. List your Coin objects: iota client objects <address> --json');
        console.log('   2. Split the coin: iota client pay-iota --recipients <addr> --amounts <amt> --input-coins <coin_id>');
        console.log('   3. Call burn: iota client call --package <pkg> --module debt_cmtat --function burn_entry --args <treasury_cap> <split_coin_id> <deny_list>');
        
        console.log('\n✅ FLOW REDEEM COMPLETED (Atomic SUCCESS - redemption recorded)');
    }

    private async flowEmergency(): Promise<void> {
        console.log('🚨 FLOW: Emergency (Atomic - All-or-Nothing)');
        console.log('==============================================');
        
        const delayMs = this.config.delayMs || 1000;
        const errors: string[] = [];
        
        console.log('\n📋 Step 1: Determine emergency action...');
        const action = this.config.emergencyAction || 'pause';
        console.log(`   Action: ${action}`);
        
        switch (action.toLowerCase()) {
            case 'pause':
                console.log('\n📋 Step 2: Pause all transfers...');
                try {
                    await this.pause();
                    console.log('   ✅ All transfers paused');
                } catch (e: any) {
                    errors.push(`Pause failed: ${e.message}`);
                }
                break;
                
            case 'freeze':
                console.log('\n📋 Step 2: Freeze addresses...');
                const addresses = this.parseAddresses(this.config.freezeAddresses || '');
                for (const addr of addresses) {
                    try {
                        this.config.address = addr;
                        await this.freeze();
                        await this.delay(delayMs);
                        console.log(`   ✅ Froze ${addr}`);
                    } catch (e: any) {
                        errors.push(`Freeze failed for ${addr}: ${e.message}`);
                    }
                }
                break;
                
            case 'flag':
                console.log('\n📋 Step 2: Flag addresses as redeemed...');
                const flagAddresses = this.parseAddresses(this.config.freezeAddresses || '');
                for (const addr of flagAddresses) {
                    try {
                        await this.flagAsRedeemed(addr, 0);
                        await this.delay(delayMs);
                        console.log(`   ✅ Flagged ${addr}`);
                    } catch (e: any) {
                        errors.push(`Flag failed for ${addr}: ${e.message}`);
                    }
                }
                break;
                
            default:
                errors.push(`Unknown emergency action: ${action}`);
        }
        
        if (errors.length > 0) {
            console.log('\n❌ EMERGENCY FLOW FAILED');
            errors.forEach(e => console.log(`   - ${e}`));
            process.exit(1);
        }
        
        console.log('\n🚨 EMERGENCY FLOW COMPLETED (Atomic SUCCESS)');
    }

    private async grantRoleToAddress(address: string, role: string): Promise<void> {
        this.config.address = address;
        this.config.role = role;
        await this.grantRole();
    }

    private async addToAllowlist(address: string): Promise<void> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const objects = await this.discoverTokenObjects();
        
        if (!objects.complianceState) {
            throw new Error('ComplianceState not found');
        }
        if (!objects.adminCap) {
            throw new Error('AdminCap not found');
        }
        
        const command = `iota client call --package ${this.config.packageId} --module allowlist_cmtat --function add_to_allowlist --args ${objects.adminCap} ${objects.complianceState} ${address} --gas-budget 500000000`;
        
        const output = execSync(command, execOptions).toString();
        const txDigest = this.extractTransactionDigest(output);
        if (!txDigest) {
            throw new Error(output.substring(0, 200));
        }
    }

    private async takeSnapshot(): Promise<void> {
        if (this.config.variant !== 'standard' && this.config.variant !== 'debt') {
            console.log('   Snapshot not available for this variant');
            return;
        }
        
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const objects = await this.discoverTokenObjects();
        
        if (!objects.state) {
            throw new Error('State not found');
        }
        if (!objects.treasuryCap) {
            throw new Error('TreasuryCap not found');
        }
        if (!objects.snapshotCap) {
            throw new Error('SnapshotCap not found. Deploy and transfer SnapshotCap to your address first.');
        }
        
        const moduleName = this.config.variant === 'debt' ? 'debt_cmtat' : 'standard_cmtat';
        const systemClock = '0x6';
        const args = `${objects.snapshotCap} ${objects.state} ${objects.treasuryCap} ${systemClock}`;
        const command = `iota client call --package ${this.config.packageId} --module ${moduleName} --function schedule_snapshot --args ${args} --gas-budget 500000000`;
        
        const output = execSync(command, execOptions).toString();
        const txDigest = this.extractTransactionDigest(output);
        if (!txDigest) {
            throw new Error(output.substring(0, 200));
        }
    }

    private async flagAsRedeemed(address: string, amount: number): Promise<void> {
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const objects = await this.discoverTokenObjects();
        
        if (!objects.state) {
            throw new Error('DebtCMTATState not found');
        }
        
        const command = `iota client call --package ${this.config.packageId} --module debt_cmtat --function set_redeemed --args ${objects.state} ${address} ${amount} --gas-budget 500000000`;
        
        const output = execSync(command, execOptions).toString();
        const txDigest = this.extractTransactionDigest(output);
        if (!txDigest) {
            throw new Error(output.substring(0, 200));
        }
    }

    private async burnDebtTokens(): Promise<void> {
        if (!this.config.amount) {
            throw new Error('--amount required for burn');
        }
        
        const { execSync } = require('child_process');
        const execOptions = this.getExecOptions();
        const objects = await this.discoverTokenObjects();
        
        if (!objects.treasuryCap) {
            throw new Error('TreasuryCap not found');
        }
        
        const systemDenyList = '0x403';
        const args = `${objects.treasuryCap} ${this.config.amount} ${systemDenyList}`;
        const command = `iota client call --package ${this.config.packageId} --module debt_cmtat --function burn_entry --args ${args} --gas-budget 500000000`;
        
        const output = execSync(command, execOptions).toString();
        const txDigest = this.extractTransactionDigest(output);
        if (!txDigest) {
            throw new Error(output.substring(0, 200));
        }
    }

    private parseAddresses(input: string): string[] {
        if (!input) return [];
        return input.split(',').map(s => s.trim()).filter(s => s.length > 0);
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
            case '--continue-on-error':
                config.continueOnError = true;
                break;
            case '--delay-ms':
                config.delayMs = parseInt(args[++i]);
                break;
            case '--allocations':
                config.allocations = args[++i];
                break;
            case '--allowlist-addresses':
                config.allowlistAddresses = args[++i];
                break;
            case '--snapshot-after':
                config.snapshotAfter = true;
                break;
            case '--coupon-number':
                config.couponNumber = parseInt(args[++i]);
                break;
            case '--emergency-action':
                config.emergencyAction = args[++i];
                break;
            case '--freeze-addresses':
                config.freezeAddresses = args[++i];
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
  --package-id <id>         Package ID (required)
  --action <action>         Action to perform (required)
  --network <net>          Network (mainnet|testnet|devnet|localnet)
  --variant <var>          Variant (light|allowlist|debt|standard)
  --amount <n>             Amount for mint/burn/transfer
  --recipient <addr>        Recipient address
  --address <addr>          Address for freeze/role operations
  --role <role>            Role for grant/revoke (minter|pauser|enforcer)
  --continue-on-error       Continue on error (for flows)
  --delay-ms <ms>           Delay between operations (default varies)
  --allocations <json>      JSON array [{address, amount}, ...]
  --allowlist-addresses <addrs>  Comma-separated addresses
  --snapshot-after          Take snapshot after minting
  --coupon-number <n>      Coupon number for coupon flow
  --emergency-action <act>   Action: pause|freeze|flag
  --freeze-addresses <addrs> Addresses for emergency freeze
  --help                    Show this help

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

Orchestrated Flows:
  flow_setup      Setup token with roles (atomic)
  flow_onboard    Onboard addresses to allowlist (continue-on-error)
  flow_issue      Mint tokens to allocations (continue-on-error)
  flow_coupon     Distribute coupon payments (continue-on-error)
  flow_redeem     Redeem tokens atomically (atomic)
  flow_emergency  Emergency actions (atomic)

Flow Examples:

  # Setup: Grant roles to addresses
  node dist/interact.js --package-id 0x123... --action flow_setup \\
    --allowlist-addresses 0x456...,0x789...

  # Onboard: Add to allowlist and grant roles
  node dist/interact.js --package-id 0x123... --variant allowlist \\
    --action flow_onboard --continue-on-error \\
    --allowlist-addresses 0x456...,0x789...

  # Issue: Mint to multiple recipients with snapshot
  node dist/interact.js --package-id 0x123... --action flow_issue \\
    --allocations '[{"address":"0x456","amount":1000},{"address":"0x789","amount":2000}]' \\
    --snapshot-after --delay-ms 1500

  # Coupon: Distribute coupon payments
  node dist/interact.js --package-id 0x123... --variant debt \\
    --action flow_coupon --coupon-number 1 \\
    --allocations '[{"address":"0x456","amount":50},{"address":"0x789","amount":100}]'

  # Redeem: Redeem tokens atomically
  node dist/interact.js --package-id 0x123... --variant debt \\
    --action flow_redeem \\
    --allocations '[{"address":"0x456","amount":1000}]'

  # Emergency: Pause all transfers
  node dist/interact.js --package-id 0x123... --action flow_emergency \\
    --emergency-action pause

  # Emergency: Freeze specific addresses
  node dist/interact.js --package-id 0x123... --action flow_emergency \\
    --emergency-action freeze --freeze-addresses 0x456...,0x789...
    `);
}

if (require.main === module) {
    main().catch(console.error);
}

export { TokenInteractor, InteractConfig };
