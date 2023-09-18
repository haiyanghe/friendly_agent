// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IFriendtechSharesV1 {
    function getBuyPriceAfterFee(
        address sharesSubject,
        uint256 amount
    ) external view returns (uint256);

    function getSellPriceAfterFee(
        address sharesSubject,
        uint256 amount
    ) external view returns (uint256);

    function buyShares(address sharesSubject, uint256 amount) external payable;

    function sellShares(address sharesSubject, uint256 amount) external payable;
}

interface IERC20 {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

contract FriendlyAgent {
    error FriendlyAgent__NotOwner();
    error FriendlyAgent__AmountGreaterThanHoldings();
    error FriendlyAgent__OverMaxLimit();
    error FriendlyAgent__UnderMinLimit();

    IFriendtechSharesV1 public immutable i_friendtechShares;
    address public immutable i_owner;
    mapping(address => uint256) private s_holdings; // recommend passing this public

    constructor(address _friendtechSharesAddress) {
        i_friendtechShares = IFriendtechSharesV1(_friendtechSharesAddress);
        i_owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) {
            revert FriendlyAgent__NotOwner();
        }
        _;
    }

    function buyShares(
        uint256 maxPrice,
        uint256 amount,
        address sharesSubject
    ) public payable onlyOwner {
        uint256 priceAfterFee = i_friendtechShares.getBuyPriceAfterFee(
            sharesSubject,
            amount
        );
        if (priceAfterFee > maxPrice) {
            revert FriendlyAgent__OverMaxLimit();
        }

        s_holdings[sharesSubject] += amount;
        i_friendtechShares.buyShares{value: priceAfterFee}(
            sharesSubject,
            amount
        );
    }

    function sellShares(
        uint256 minPrice,
        uint256 amount,
        address sharesSubject
    ) public onlyOwner {
        if (s_holdings[sharesSubject] < amount) {
            // Useless check, if not true, `s_holdings[sharesSubject] -= amount` will revert
            revert FriendlyAgent__AmountGreaterThanHoldings();
        }
        uint256 priceAfterFee = i_friendtechShares.getSellPriceAfterFee(
            sharesSubject,
            amount
        );
        if (priceAfterFee < minPrice) {
            revert FriendlyAgent__UnderMinLimit();
        }

        s_holdings[sharesSubject] -= amount;
        i_friendtechShares.sellShares{value: 0}(sharesSubject, amount);
    }

    function withdraw() public onlyOwner {
        (bool callSuccess, ) = payable(i_owner).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call failed");
    }

    function withdrawToken(address tokenAddress) public onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(token.transfer(i_owner, balance), "Token transfer failed");
        // Previous require will not work with every ERC-20
        // Recommend to implement the following:
        // function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // bytes memory returndata = address(token).functionCall(data);
        // if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
        //     revert SafeERC20FailedOperation(address(token));
        // }
    }

    function getHoldings(
        address sharesSubject
    ) external view returns (uint256) {
        // Can be removed if s_holdings is changed to public
        return s_holdings[sharesSubject];
    }

    fallback() external payable {}

    receive() external payable {}
}
