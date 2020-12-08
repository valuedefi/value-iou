import {deployments, ethers} from 'hardhat';
import {expect} from './chai-setup';

import {
    fromWei,
    toWei,
    toWeiString,
    mineBlocks,
    maxUint256,
    ADDRESS_ZERO
} from './shared/utilities';

import {
    // @ts-ignore
    ValueIou,
    ValueIouFactory
} from '../../typechain';

import {SignerWithAddress} from 'hardhat-deploy-ethers/dist/src/signer-with-address';

const verbose = process.env.VERBOSE;

const INIT_BALANCE = toWei('1000');

describe('001_valueiou.test', function () {
    let signers: SignerWithAddress[];
    let deployer: SignerWithAddress;
    let bob: SignerWithAddress;

    let valueIou: ValueIou;

    before(async function () {
        signers = await ethers.getSigners();
        deployer = signers[0];
        bob = signers[1];

        await deployments.fixture(['ValueIOU']);

        valueIou = await ethers.getContract('ValueIOU') as ValueIou;
    })

    describe('valueIou should work', () => {
        it('constructor parameters should be correct', async () => {
            // 'mvStablesBond', 'mvUSDBond', 18
            expect(await valueIou.name()).is.eq('mvStablesBond');
            expect(await valueIou.symbol()).is.eq('mvUSDBond');
            expect(await valueIou.decimals()).is.eq(18);
        });
    });
});
