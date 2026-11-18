// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title AevumPay — invoice escrow for tUSD8 stablecoin payments
/// @notice A minimal, auditable escrow for one end-to-end stablecoin payment
///         flow on the QDay Aevum testnet (chain ID 44005):
///         create invoice -> approve tUSD8 -> fund (escrow) -> payer confirms
///         delivery -> funds release to the merchant. If the payer never
///         confirms and the invoice expires, the payer can refund.
/// @dev Zero-dependency, single file, so the deployed source verifies cleanly
///      on the Blockscout explorer. Testnet only; tUSD8 has no real value.
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

contract AevumPay {
    /// @notice The stablecoin held in escrow (tUSD8 on Aevum testnet).
    IERC20 public immutable token;

    /// @notice Next invoice id (also the count of invoices created).
    uint256 public nextInvoiceId;

    enum Status {
        Created, // invoice exists, not yet funded
        Funded, // tUSD8 locked in escrow
        Released, // confirmed: funds sent to merchant
        Refunded, // expired: funds returned to payer
        Cancelled // created but never funded, cancelled by payer
    }

    struct Invoice {
        uint256 id;
        address payer;
        address merchant;
        uint256 amount;
        uint256 expiresAt;
        Status status;
        string memo;
    }

    mapping(uint256 => Invoice) public invoices;

    event InvoiceCreated(
        uint256 indexed id, address indexed payer, address indexed merchant, uint256 amount, uint256 expiresAt, string memo
    );
    event InvoiceFunded(uint256 indexed id, address indexed payer, uint256 amount);
    event InvoiceReleased(uint256 indexed id, address indexed merchant, uint256 amount);
    event InvoiceRefunded(uint256 indexed id, address indexed payer, uint256 amount);
    event InvoiceCancelled(uint256 indexed id);

    // Minimal reentrancy guard (no external dependencies).
    uint256 private _locked;

    modifier nonReentrant() {
        require(_locked == 0, "REENTRANT");
        _locked = 1;
        _;
        _locked = 0;
    }

    constructor(address token_) {
        require(token_ != address(0), "ZERO_TOKEN");
        token = IERC20(token_);
    }

    /// @notice Create an invoice. The caller becomes the payer.
    /// @param merchant Who receives the funds on confirmation.
    /// @param amount tUSD8 amount in atomic units (tUSD8 has 6 decimals).
    /// @param expirySeconds How long the payer has to confirm after funding.
    /// @param memo Free-text reference (e.g. order id).
    function createInvoice(address merchant, uint256 amount, uint256 expirySeconds, string calldata memo)
        external
        returns (uint256 id)
    {
        require(merchant != address(0), "ZERO_MERCHANT");
        require(merchant != msg.sender, "SELF_PAY");
        require(amount > 0, "ZERO_AMOUNT");
        require(expirySeconds > 0, "ZERO_EXPIRY");

        id = nextInvoiceId++;
        invoices[id] = Invoice({
            id: id,
            payer: msg.sender,
            merchant: merchant,
            amount: amount,
            expiresAt: block.timestamp + expirySeconds,
            status: Status.Created,
            memo: memo
        });
        emit InvoiceCreated(id, msg.sender, merchant, amount, block.timestamp + expirySeconds, memo);
    }

    /// @notice Fund an invoice: pulls `amount` tUSD8 from the payer into escrow.
    /// @dev Payer must have approved this contract for at least `amount` first.
    function fundInvoice(uint256 id) external nonReentrant {
        Invoice storage inv = invoices[id];
        require(inv.payer == msg.sender, "NOT_PAYER");
        require(inv.status == Status.Created, "NOT_CREATED");
        require(block.timestamp <= inv.expiresAt, "EXPIRED");
        inv.status = Status.Funded; // effects before interaction
        require(token.transferFrom(msg.sender, address(this), inv.amount), "TRANSFER_FAILED");
        emit InvoiceFunded(id, msg.sender, inv.amount);
    }

    /// @notice Payer confirms delivery: escrowed tUSD8 goes to the merchant.
    function confirmDelivery(uint256 id) external nonReentrant {
        Invoice storage inv = invoices[id];
        require(inv.payer == msg.sender, "NOT_PAYER");
        require(inv.status == Status.Funded, "NOT_FUNDED");
        inv.status = Status.Released; // effects before interaction
        require(token.transfer(inv.merchant, inv.amount), "TRANSFER_FAILED");
        emit InvoiceReleased(id, inv.merchant, inv.amount);
    }

    /// @notice After expiry, the payer can reclaim escrowed tUSD8.
    function refundInvoice(uint256 id) external nonReentrant {
        Invoice storage inv = invoices[id];
        require(inv.payer == msg.sender, "NOT_PAYER");
        require(inv.status == Status.Funded, "NOT_FUNDED");
        require(block.timestamp > inv.expiresAt, "NOT_EXPIRED");
        inv.status = Status.Refunded; // effects before interaction
        require(token.transfer(inv.payer, inv.amount), "TRANSFER_FAILED");
        emit InvoiceRefunded(id, inv.payer, inv.amount);
    }

    /// @notice Cancel an invoice that was never funded. No funds move.
    function cancelInvoice(uint256 id) external {
        Invoice storage inv = invoices[id];
        require(inv.payer == msg.sender, "NOT_PAYER");
        require(inv.status == Status.Created, "NOT_CREATED");
        inv.status = Status.Cancelled;
        emit InvoiceCancelled(id);
    }

    /// @notice Read a full invoice (the public mapping getter returns fields
    ///         one by one; this returns the whole struct for UIs).
    function getInvoice(uint256 id) external view returns (Invoice memory) {
        return invoices[id];
    }
}
