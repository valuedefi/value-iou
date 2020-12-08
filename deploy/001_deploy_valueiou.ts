import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
	const {deployments, getNamedAccounts} = hre;
	const {deploy, get, read, execute, getOrNull, log} = deployments;
	const {deployer} = await getNamedAccounts();

	const iou = await deploy('ValueIOU', {
		contract: 'ValueIOU',
		skipIfAlreadyDeployed: true,
		from: deployer,
		args: [],
		log: true,
	});

	if (iou.newlyDeployed) {
		await execute('ValueIOU', {from: deployer}, 'initialize',
			'mvStablesBond', 'mvUSDBond', 18
		)
	}
};

export default func;
func.tags = ['ValueIOU'];
