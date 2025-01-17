pragma solidity >=0.8.4;
pragma experimental ABIEncoderV2;

import "../registry/ENS.sol";
import "./ETHRegistrarController.sol";
import "./IETHRegistrarController.sol";
import "../resolvers/Resolver.sol";
import "./IBulkRenewal.sol";
import "./IPriceOracle.sol";

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract BulkRenewal is IBulkRenewal {
    bytes32 private constant ETH_NAMEHASH =
        0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;

    ENS public immutable ens;

    constructor(ENS _ens) {
        ens = _ens;
    }

    function getController() internal view returns (ETHRegistrarController) {
        Resolver r = Resolver(ens.resolver(ETH_NAMEHASH));
        return
            ETHRegistrarController(
                r.interfaceImplementer(
                    ETH_NAMEHASH,
                    type(IETHRegistrarController).interfaceId
                )
            );
    }

    function rentPrice(string[] calldata names, uint256 duration)
        external
        view
        override
        returns (uint256 total)
    {
        ETHRegistrarController controller = getController();
        for (uint256 i = 0; i < names.length; i++) {
            IPriceOracle.Price memory price = controller.rentPrice(
                names[i],
                duration
            );
            total += (price.base + price.premium);
        }
    }

    function renewAll(
        string[] calldata names,
        uint256 duration,
        address referrer
    ) external payable override {
        ETHRegistrarController controller = getController();
        for (uint256 i = 0; i < names.length; i++) {
            IPriceOracle.Price memory price = controller.rentPrice(
                names[i],
                duration
            );
            controller.renew{value: price.base}(names[i], duration, referrer);
        }

        // Send any excess funds back
        (bool ok, ) = msg.sender.call{value: address(this).balance}("");
        require(ok, "BulkRenewal: failed to refund renew excess");
    }

    function supportsInterface(bytes4 interfaceID)
        external
        pure
        returns (bool)
    {
        return
            interfaceID == type(IERC165).interfaceId ||
            interfaceID == type(IBulkRenewal).interfaceId;
    }
}
