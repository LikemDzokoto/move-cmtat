export type IotaAddress = string;

export class CoinHelper {
    private client: any;
    private senderAddress: IotaAddress;

    constructor(client: any, senderAddress: IotaAddress) {
        this.client = client;
        this.senderAddress = senderAddress;
    }

    async getCoins(coinType: string): Promise<{ objectId: string; balance: number }[]> {
        const coins = await this.client.getCoins({
            owner: this.senderAddress,
            coinType: coinType,
        });
        
        return coins.data.map((coin: any) => ({
            objectId: coin.coinObjectId,
            balance: parseInt(coin.balance)
        }));
    }

    async getCoinObjects(coinType: string): Promise<{ objectId: string; version: string; digest: string; balance: number }[]> {
        const coins = await this.client.getCoins({
            owner: this.senderAddress,
            coinType: coinType,
        });
        
        return coins.data.map((coin: any) => ({
            objectId: coin.coinObjectId,
            version: coin.version,
            digest: coin.digest,
            balance: parseInt(coin.balance)
        }));
    }
}

export function getCoinTypeFromPackage(packageId: string, variant: string): string {
    const coinTypeMap: Record<string, string> = {
        light: 'LIGHT_CMTAT',
        allowlist: 'ALLOWLIST_CMTAT',
        debt: 'DEBT_CMTAT',
        standard: 'STANDARD_CMTAT'
    };
    
    const coinType = coinTypeMap[variant] || variant.toUpperCase();
    return `${packageId}::${variant}_cmtat::${coinType}`;
}
