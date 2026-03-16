import { IotaClient } from '@iota/iota-sdk/client';
import { Ed25519Keypair } from '@iota/iota-sdk/keypairs/ed25519';
import { Transaction } from '@iota/iota-sdk/transactions';
import { bcs } from '@iota/iota-sdk/bcs';

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
    private client: IotaClient;
    private keypair: Ed25519Keypair;
    private config: InteractConfig;

    constructor(config: InteractConfig) {
        this.config = config;
        this.client = new IotaClient({ url: this.getRpcUrl(config.network) });

        if (config.privateKey) {
            this.keypair = Ed25519Keypair.fromSecretKey(
                Buffer.from(config.privateKey, 'hex')
            );
        } else {
            this.keypair = new Ed25519Keypair();
        }
    }

    private getRpcUrl(network: string): string {
        const urls: Record<string, string> = {
            mainnet: 'https://api.mainnet.iota.org:443',
            testnet: 'https://api.testnet.iota.org:443',
            devnet: 'https://api.devnet.iota.org:443',
            localnet: 'http://127.0.0.1:9000',
        };
        return urls[network] || urls.testnet;
    }

    async run(): Promise<void> {
        console.log('\n🚀 Token Interaction');
        console.log('==================================');
        console.log(`Network: ${this.config.network}`);
        console.log(`Action: ${this.config.action}`);
        console.log(`Package: ${this.config.packageId}`);
        console.log(`Signer: ${this.keypair.getPublicKey().toIotaAddress()}`);
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

        const tx = new Transaction();
        tx.moveCall({
            target: `${this.config.packageId}::${this.config.variant}_cmtat::mint`,
            arguments: [
                tx.pure(bcs.string().serialize(this.config.recipient).toBytes()),
                tx.pure(bcs.u64().serialize(this.config.amount).toBytes()),
            ],
        });

        const result = await this.executeTx(tx);
        console.log(`✅ Minted ${this.config.amount} tokens to ${this.config.recipient}`);
        console.log(`   Digest: ${result.digest}`);
    }

    private async burn(): Promise<void> {
        if (!this.config.amount) {
            console.log('ERROR: --amount required for burn');
            process.exit(1);
        }

        const coins = await this.getCoins();
        if (coins.data.length === 0) {
            console.log('ERROR: No tokens to burn');
            process.exit(1);
        }

        const total = coins.data.reduce((sum, c) => sum + Number(c.balance), 0);
        if (total < this.config.amount!) {
            console.log(`ERROR: Insufficient balance. Have ${total}, need ${this.config.amount}`);
            process.exit(1);
        }

        const tx = new Transaction();
        const coin = tx.splitCoins(tx.gas, [tx.pure(bcs.u64().serialize(this.config.amount).toBytes())]);
        tx.moveCall({
            target: `${this.config.packageId}::${this.config.variant}_cmtat::burn`,
            arguments: [coin],
        });

        const result = await this.executeTx(tx);
        console.log(`✅ Burned ${this.config.amount} tokens`);
        console.log(`   Digest: ${result.digest}`);
    }

    private async transfer(): Promise<void> {
        if (!this.config.amount || !this.config.recipient) {
            console.log('ERROR: --amount and --recipient required for transfer');
            process.exit(1);
        }

        const tx = new Transaction();
        const coin = tx.splitCoins(tx.gas, [tx.pure(bcs.u64().serialize(this.config.amount).toBytes())]);
        tx.transferObjects([coin], tx.pure(bcs.string().serialize(this.config.recipient).toBytes()));

        const result = await this.executeTx(tx);
        console.log(`✅ Transferred ${this.config.amount} tokens to ${this.config.recipient}`);
        console.log(`   Digest: ${result.digest}`);
    }

    private async pause(): Promise<void> {
        const tx = new Transaction();
        tx.moveCall({
            target: `${this.config.packageId}::${this.config.variant}_cmtat::pause`,
            arguments: [],
        });

        const result = await this.executeTx(tx);
        console.log('✅ Token transfers paused');
        console.log(`   Digest: ${result.digest}`);
    }

    private async unpause(): Promise<void> {
        const tx = new Transaction();
        tx.moveCall({
            target: `${this.config.packageId}::${this.config.variant}_cmtat::unpause`,
            arguments: [],
        });

        const result = await this.executeTx(tx);
        console.log('✅ Token transfers unpaused');
        console.log(`   Digest: ${result.digest}`);
    }

    private async freeze(): Promise<void> {
        if (!this.config.address) {
            console.log('ERROR: --address required for freeze');
            process.exit(1);
        }

        const tx = new Transaction();
        tx.moveCall({
            target: `${this.config.packageId}::${this.config.variant}_cmtat::freeze`,
            arguments: [tx.pure(bcs.string().serialize(this.config.address).toBytes())],
        });

        const result = await this.executeTx(tx);
        console.log(`✅ Froze address ${this.config.address}`);
        console.log(`   Digest: ${result.digest}`);
    }

    private async unfreeze(): Promise<void> {
        if (!this.config.address) {
            console.log('ERROR: --address required for unfreeze');
            process.exit(1);
        }

        const tx = new Transaction();
        tx.moveCall({
            target: `${this.config.packageId}::${this.config.variant}_cmtat::unfreeze`,
            arguments: [tx.pure(bcs.string().serialize(this.config.address).toBytes())],
        });

        const result = await this.executeTx(tx);
        console.log(`✅ Unfroze address ${this.config.address}`);
        console.log(`   Digest: ${result.digest}`);
    }

    private async grantRole(): Promise<void> {
        if (!this.config.address || !this.config.role) {
            console.log('ERROR: --address and --role required for grant_role');
            process.exit(1);
        }

        const roleBytes = this.getRoleBytes(this.config.role);

        const tx = new Transaction();
        tx.moveCall({
            target: `${this.config.packageId}::${this.config.variant}_cmtat::grant_role`,
            arguments: [
                tx.pure(bcs.string().serialize(this.config.address).toBytes()),
                tx.pure(new Uint8Array(roleBytes)),
            ],
        });

        const result = await this.executeTx(tx);
        console.log(`✅ Granted ${this.config.role} to ${this.config.address}`);
        console.log(`   Digest: ${result.digest}`);
    }

    private async revokeRole(): Promise<void> {
        if (!this.config.address || !this.config.role) {
            console.log('ERROR: --address and --role required for revoke_role');
            process.exit(1);
        }

        const roleBytes = this.getRoleBytes(this.config.role);

        const tx = new Transaction();
        tx.moveCall({
            target: `${this.config.packageId}::${this.config.variant}_cmtat::revoke_role`,
            arguments: [
                tx.pure(bcs.string().serialize(this.config.address).toBytes()),
                tx.pure(new Uint8Array(roleBytes)),
            ],
        });

        const result = await this.executeTx(tx);
        console.log(`✅ Revoked ${this.config.role} from ${this.config.address}`);
        console.log(`   Digest: ${result.digest}`);
    }

    private async getBalance(): Promise<void> {
        const address = this.config.address || this.keypair.getPublicKey().toIotaAddress();
        
        const coins = await this.client.getCoins({
            owner: address,
        });

        const total = coins.data.reduce((sum, c) => sum + Number(c.balance), 0);
        
        console.log(`Balance for ${address}:`);
        console.log(`   Total: ${total}`);
        console.log(`   Coin count: ${coins.data.length}`);
    }

    private async getTokenInfo(): Promise<void> {
        try {
            const objects = await this.client.getOwnedObjects({
                owner: this.config.packageId,
            });

            const registry = objects.data.find((o: any) => 
                o.data?.type?.includes('Registry') || o.data?.type?.includes('State')
            );

            console.log('Token Info:');
            console.log(`   Package ID: ${this.config.packageId}`);
            console.log(`   Variant: ${this.config.variant}`);
            
            if (registry) {
                console.log(`   Registry ID: ${registry.data.objectId}`);
            }

            const coins = await this.client.getCoins({
                owner: this.config.packageId,
                coinType: `${this.config.packageId}::${this.config.variant}_cmtat::${this.config.variant.toUpperCase()}_CMTAT`,
            });

            if (coins.data.length > 0) {
                console.log(`   Treasury: ${coins.data[0].balance}`);
            }
        } catch (error) {
            console.log('Error fetching token info:', error);
        }
    }

    private async getCoins() {
        return this.client.getCoins({
            owner: this.keypair.getPublicKey().toIotaAddress(),
            coinType: `${this.config.packageId}::${this.config.variant}_cmtat::${this.config.variant.toUpperCase()}_CMTAT`,
        });
    }

    private async executeTx(tx: Transaction): Promise<any> {
        return this.client.signAndExecuteTransaction({
            signer: this.keypair,
            transaction: tx,
            options: {
                showEffects: true,
                showObjectChanges: true,
            },
        });
    }

    private getRoleBytes(role: string): number[] {
        const roles: Record<string, string> = {
            admin: 'DEFAULT_ADMIN_ROLE',
            minter: 'MINTER_ROLE',
            pauser: 'PAUSER_ROLE',
            enforcer: 'ENFORCER_ROLE',
            default_admin: 'DEFAULT_ADMIN_ROLE',
        };

        const roleName = roles[role.toLowerCase()] || role.toUpperCase();
        return Array.from(Buffer.from(roleName));
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
  ts-node interact.ts [options]

Options:
  --package-id <id>    Package ID (required)
  --action <action>   Action to perform (required)
  --network <net>     Network (mainnet|testnet|devnet|localnet)
  --private-key <key> Private key (hex)
  --variant <var>     Variant (light|allowlist|debt|standard)
  --amount <n>        Amount for mint/burn/transfer
  --recipient <addr>  Recipient address
  --address <addr>    Address for freeze/role operations
  --role <role>       Role for grant/revoke (admin|minter|pauser|enforcer)
  --help              Show this help

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
  ts-node interact.ts --package-id 0x123... --action mint --amount 1000 --recipient 0x456...
  ts-node interact.ts --package-id 0x123... --action balance --address 0x456...
  ts-node interact.ts --package-id 0x123... --action pause
  ts-node interact.ts --package-id 0x123... --action freeze --address 0x456...
    `);
}

if (require.main === module) {
    main().catch(console.error);
}

export { TokenInteractor, InteractConfig };
