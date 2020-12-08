import {Contract, BigNumber, BigNumberish} from 'ethers'
import AllBigNumber from "bignumber.js";
import path from "path";
import {ethers} from "hardhat";

export const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000'
export const maxUint256 = BigNumber.from(2).pow(256).sub(1)
export const maxInt128 = BigNumber.from(2).pow(128).sub(1)

export function logDeployedContract(name: string, contract: Contract) {
	console.log(`Deployed contract:${name} address=${contract.address}, tx:${contract.deployTransaction.hash}`)
}

export async function unlockForkAddress(ethers: any, address: string): Promise<any> {
	return ethers.provider.send('hardhat_impersonateAccount', [address]);
}

export async function unlockForkAddresses(ethers: any, addresses: string[]): Promise<any[]> {
	return Promise.all(addresses.map(address => unlockForkAddress(ethers, address)))
}

export async function forkBlockNumber(ethers: any, blockNumber: number): Promise<any> {
	await ethers.provider.send(
		"hardhat_reset",
		[{
			forking: {
				blockNumber: blockNumber,
				jsonRpcUrl: `https://eth-mainnet.alchemyapi.io/v2/he0SsGB4TG7GXBaKDNS6xKaW0-knGo1q`
			},
		}]
	);
}

export async function lockForkAddress(ethers: any, address: string): Promise<any> {
	return ethers.provider.send('hardhat_stopImpersonatingAccount', [address]);
}

export async function isNotDeployed(deployments: any, name: string): Promise<boolean> {
	let contract = await deployments.getOrNull(name);
	return contract == null || contract.address == null
}

export async function isDeployed(deployments: any, name: string): Promise<boolean> {
	let contract = await deployments.getOrNull(name);
	return contract && contract.address != null
}

export function toWei(n: BigNumberish): BigNumber {
	return expandDecimals(n, 18)
}

export function toWeiString(n: BigNumberish): string {
	return expandDecimalsString(n, 18)
}

export function fromWei(n: BigNumberish): string {
	return collapseDecimals(n, 18)
}

export function expandDecimals(n: BigNumberish, decimals = 18): BigNumber {
	return BigNumber.from(new AllBigNumber(n.toString()).multipliedBy(new AllBigNumber(10).pow(decimals)).toFixed())
}

export function expandDecimalsString(n: BigNumberish, decimals = 18): string {
	return new AllBigNumber(n.toString()).multipliedBy(new AllBigNumber(10).pow(decimals)).toFixed()
}

export function collapseDecimals(n: BigNumberish, decimals = 18): string {
	return new AllBigNumber(n.toString()).div(new AllBigNumber(10).pow(decimals)).toFixed()
}

export async function mineBlocks(ethers: any, blocks: number): Promise<any> {
	for (let i = 0; i < blocks; i++) {
		await mineBlock(ethers)
	}
}

export async function mineBlockTimeStamp(ethers: any, timestamp: number): Promise<any> {
	return ethers.provider.send('evm_mine', [timestamp]);
}

export async function mineBlock(ethers: any): Promise<any> {
	return ethers.provider.send('evm_mine', []);
}

export async function getLatestBlockNumber(ethers: any): Promise<number> {
	return (await getLatestBlock(ethers)).number
}

export async function getLatestBlock(ethers: any): Promise<{
	hash: string;
	parentHash: string;
	number: number;
	timestamp: number;
	nonce: string;
	difficulty: number;
	gasLimit: BigNumber;
	gasUsed: BigNumber;
	miner: string;
	extraData: string;
}> {
	return await ethers.provider.getBlock("latest")
}
