import { CoinHelper, IotaAddress } from './CoinHelper';
export { getCoinTypeFromPackage } from './CoinHelper';

export interface TransferResult {
    success: boolean;
    digest?: string;
    error?: string;
}

export class TokenHelper {
    private senderAddress: IotaAddress;

    constructor(senderAddress: IotaAddress) {
        this.senderAddress = senderAddress;
    }

    async transferTokens(
        packageId: string,
        variant: string,
        recipient: IotaAddress,
        amount: number
    ): Promise<TransferResult> {
        try {
            const { execSync } = require('child_process');
            const execOptions = { stdio: ['pipe', 'pipe', 'pipe'] as any, maxBuffer: 50 * 1024 * 1024 };

            let command: string;
            if (variant === 'light') {
                const registry = await this.findRegistry(packageId, variant);
                const denyList = '0x403';
                command = `iota client call --package ${packageId} --module ${variant}_cmtat --function transfer --args ${registry} ${denyList} @${recipient} ${amount} --gas-budget 500000000`;
            } else {
                command = `iota client pay-iota --recipients ${recipient} --amounts ${amount} --gas-budget 50000000`;
            }

            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractDigest(output);
            
            return { success: true, digest: txDigest };
        } catch (error: any) {
            return { success: false, error: error.message || String(error) };
        }
    }

    async createConditionalTransferRequest(
        packageId: string,
        variant: string,
        to: IotaAddress,
        amount: number
    ): Promise<TransferResult> {
        try {
            const state = await this.findState(packageId, variant);
            if (!state) {
                return { success: false, error: 'State not found' };
            }

            const clock = '0x6';
            const { execSync } = require('child_process');
            const execOptions = { stdio: ['pipe', 'pipe', 'pipe'] as any, maxBuffer: 50 * 1024 * 1024 };

            const command = `iota client call --package ${packageId} --module ${variant}_cmtat --function create_transfer_request --args ${state} @${to} ${amount} ${clock} --gas-budget 500000000`;

            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractDigest(output);
            
            return { success: true, digest: txDigest };
        } catch (error: any) {
            return { success: false, error: error.message || String(error) };
        }
    }

    async approveConditionalTransfer(
        packageId: string,
        variant: string,
        from: IotaAddress,
        to: IotaAddress,
        amount: number
    ): Promise<TransferResult> {
        try {
            const state = await this.findState(packageId, variant);
            if (!state) {
                return { success: false, error: 'State not found' };
            }

            const clock = '0x6';
            const { execSync } = require('child_process');
            const execOptions = { stdio: ['pipe', 'pipe', 'pipe'] as any, maxBuffer: 50 * 1024 * 1024 };

            const command = `iota client call --package ${packageId} --module ${variant}_cmtat --function approve_request --args ${state} @${from} @${to} ${amount} ${clock} --gas-budget 500000000`;

            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractDigest(output);
            
            return { success: true, digest: txDigest };
        } catch (error: any) {
            return { success: false, error: error.message || String(error) };
        }
    }

    async burnTokens(
        packageId: string,
        variant: string,
        treasuryCap: string,
        amount: number
    ): Promise<TransferResult> {
        try {
            const denyList = '0x403';
            const { execSync } = require('child_process');
            const execOptions = { stdio: ['pipe', 'pipe', 'pipe'] as any, maxBuffer: 50 * 1024 * 1024 };

            const moduleName = variant === 'debt' ? 'debt_cmtat' : `${variant}_cmtat`;
            const functionName = variant === 'debt' ? 'burn_entry' : 'burn';

            let args: string;
            if (variant === 'debt') {
                args = `${treasuryCap} ${amount} ${denyList}`;
            } else {
                args = `${treasuryCap} ${amount}`;
            }

            const command = `iota client call --package ${packageId} --module ${moduleName} --function ${functionName} --args ${args} --gas-budget 500000000`;

            const output = execSync(command, execOptions).toString();
            const txDigest = this.extractDigest(output);
            
            return { success: true, digest: txDigest };
        } catch (error: any) {
            return { success: false, error: error.message || String(error) };
        }
    }

    private async findRegistry(packageId: string, variant: string): Promise<string | null> {
        try {
            const { execSync } = require('child_process');
            const output = execSync(`iota client objects ${this.senderAddress} --json`, { stdio: 'pipe' }).toString();
            const objects = JSON.parse(output);
            
            const registryPatterns: Record<string, string> = {
                light: 'LightCMTATRegistry',
                allowlist: 'allowlist_cmtat::CMTATRegistry',
                debt: 'debt_cmtat::CMTATRegistry',
                standard: 'standard_cmtat::CMTATRegistry'
            };
            
            const pattern = registryPatterns[variant];
            for (const obj of objects) {
                if (obj.data?.type?.includes(pattern) && obj.data.type.includes(packageId)) {
                    return obj.data.objectId;
                }
            }
        } catch {
            return null;
        }
        return null;
    }

    private async findState(packageId: string, variant: string): Promise<string | null> {
        try {
            const { execSync } = require('child_process');
            const output = execSync(`iota client objects ${this.senderAddress} --json`, { stdio: 'pipe' }).toString();
            const objects = JSON.parse(output);
            
            const statePatterns: Record<string, string> = {
                light: '',
                allowlist: 'AllowlistCMTATState',
                debt: 'DebtCMTATState',
                standard: 'StandardCMTATState'
            };
            
            const pattern = statePatterns[variant];
            if (!pattern) return null;
            
            for (const obj of objects) {
                if (obj.data?.type?.includes(pattern) && obj.data.type.includes(packageId)) {
                    return obj.data.objectId;
                }
            }
        } catch {
            return null;
        }
        return null;
    }

    private extractDigest(output: string): string | null {
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
}
