# EVM Wallet Lite

[![Build APK](https://github.com/razi-eth/evm-wallet-lite/actions/workflows/build-apk.yml/badge.svg)](https://github.com/razi-eth/evm-wallet-lite/actions/workflows/build-apk.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.22%2B-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**A lightweight, self-custodial EVM wallet for Android, with an in-app dApp browser.**

EVM Wallet Lite is built around a single idea: a mobile wallet should be small,
auditable, and honest about what it does. It has no backend, no analytics, no
account system, and no proprietary services. Your keys never leave your device,
and every transaction or signature requested by a dApp requires your explicit
approval first.

> **Status: early-stage MVP, not yet audited.** Use it with small amounts
> first, preferably on a low-fee network such as BNB Chain, and always keep
> an offline backup of your recovery phrase. See [Security](#security).

---

## Highlights

- **Self-custodial by design** — BIP-39 recovery phrase with BIP-44 derivation
  (`m/44'/60'/0'/0/0`), so the same seed can be restored in MetaMask, Trust
  Wallet, and other standard wallets. Private keys are stored only in the
  operating system's secure storage (Android Keystore / iOS Keychain).
- **In-app dApp browser** — a real EIP-1193 provider (`window.ethereum`) is
  injected into every dApp page, so Uniswap, PancakeSwap, OpenSea, and other
  dApps work directly inside the app. No WalletConnect relay is required.
- **Approval-first security model** — connecting a dApp, sending a
  transaction, and signing a message each require a separate, human-readable
  approval. Raw `eth_sign` and typed-data signing are deliberately rejected
  in this version (see [dApp security model](#dapp-security-model)).
- **Multi-chain, no API keys** — Ethereum, BNB Chain, Polygon, Arbitrum One,
  Base, and Optimism over public RPC endpoints. No sign-up, no tracking.
- **Deliberately small** — no state-management framework, no UI kit, no
  backend SDKs. Only eight direct dependencies, and the heaviest one is the
  system WebView used by the dApp browser. Release builds use per-ABI APK
  splitting, resource shrinking, and icon tree-shaking to keep installs small.

## Features

| Feature | Details |
|---|---|
| Create / import wallet | 12-word BIP-39 mnemonic, or import from a private key |
| App lock | 6-digit PIN gate; forgotten PIN can be recovered by re-importing from the mnemonic |
| Send & receive | Native coins and ERC-20 tokens |
| Balances | Native balance plus a curated list of popular ERC-20 tokens per chain |
| Transaction history | Locally stored history of transactions sent from this wallet |
| dApp browser | URL bar, quick links, EIP-1193 provider, chain switching to supported networks |
| Network switching | Six EVM chains, switchable from the wallet screen |
| Backup & wipe | View the recovery phrase in a private setting; wipe the wallet from the device |

## Supported networks

| Network | Chain ID | Currency | Explorer |
|---|---:|---|---|
| Ethereum | 1 | ETH | https://etherscan.io |
| BNB Chain | 56 | BNB | https://bscscan.com |
| Polygon | 137 | POL | https://polygonscan.com |
| Arbitrum One | 42161 | ETH | https://arbiscan.io |
| Base | 8453 | ETH | https://basescan.org |
| Optimism | 10 | ETH | https://optimistic.etherscan.io |

RPC endpoints are public, keyless defaults defined in
[`lib/models/network.dart`](lib/models/network.dart). They can be changed
there without touching any other code. For production use with higher
reliability, consider replacing them with your own dedicated endpoints.

## Getting started

### Requirements

- Flutter (stable channel, 3.22 or newer)
- Android SDK (for Android builds)
- An Android device or emulator

### Run in debug mode

```bash
flutter pub get
flutter run
```

### Build a release APK

```bash
flutter analyze
flutter build apk --release --split-per-abi --tree-shake-icons
```

The APKs are written to `build/app/outputs/flutter-apk/`. Each push to
`main` also builds release APKs automatically via GitHub Actions
([`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml));
download them from the **Actions** tab of this repository.

> **Android first.** The `ios/` folder is intentionally omitted to keep the
> repository small. To add iOS support, run `flutter create .` in this
> directory and adapt the iOS configuration as needed.

### First run

1. Create a new wallet, or import an existing one from a mnemonic or
   private key.
2. Set a 6-digit app PIN.
3. If you created a new wallet, **write down the 12-word recovery phrase
   shown once on screen and store it offline**. The app does not back it up
   anywhere else.
4. Start on BNB Chain with a small amount to verify sending, receiving, and
   dApp interaction before moving larger funds.

## Architecture

```
lib/
├── main.dart                   App entry point and top-level routing
│                               (onboarding → PIN lock → Wallet / dApps / Settings)
├── app_state.dart              The only global state (ChangeNotifier, no extra
│                               state-management package)
├── models/
│   └── network.dart            Supported chains, RPC endpoints, ERC-20 token list
├── services/
│   ├── wallet_service.dart     Mnemonic, BIP-44 derivation, PIN hash, secure storage
│   ├── rpc_service.dart        Balances, native / ERC-20 transfers, raw JSON-RPC
│   └── dapp_bridge.dart        The injected window.ethereum (EIP-1193) provider script
├── screens/
│   ├── onboarding_screen.dart  Create / import wallet
│   ├── lock_screen.dart        PIN lock
│   ├── home_screen.dart        Balances, tokens, history
│   ├── send_screen.dart        Send native / ERC-20
│   ├── receive_screen.dart     Receive address
│   ├── dapp_screen.dart        dApp browser and signing approvals
│   └── settings_screen.dart    View mnemonic, disconnect dApps, wipe wallet
└── widgets/
    └── approval_sheet.dart     Approval bottom sheet for all signing actions
```

**Design principles**

- **One state object.** `AppState` is the only global state, implemented with
  Flutter's built-in `ChangeNotifier`. This keeps the dependency graph small
  and the data flow easy to audit.
- **Keys stay in secure storage.** Private keys and mnemonics are written
  only via `flutter_secure_storage`. They are never written to plain files,
  logs, or analytics.
- **The dApp bridge is untrusted input.** Everything a dApp sends is treated
  as untrusted: it is validated, displayed for approval, and only then signed.

## dApp security model

The dApp browser injects an EIP-1193 provider, but the provider itself cannot
sign anything. All signing decisions happen in Dart, behind an approval sheet.

| dApp request | Behavior |
|---|---|
| `eth_requestAccounts` | Always asks for approval, once per origin per session. Until approved, the dApp receives no address. |
| `eth_accounts` | Returns the address only for origins already approved in this session. |
| `eth_chainId`, `net_version` | Answered from the active chain. |
| Read-only calls (`eth_call`, `eth_getBalance`, `eth_blockNumber`, …) | Forwarded verbatim to the active chain's RPC endpoint. |
| `eth_sendTransaction` | Always asks for approval with destination, value, and contract data shown. Only then signed and broadcast. |
| `personal_sign` | Always asks for approval with the full message text shown. |
| `wallet_switchEthereumChain`, `wallet_addEthereumChain` | Allowed only to chains supported by the app; anything else is rejected. |
| `eth_sign`, `eth_signTypedData*` | Rejected in this version. Typed-data signing requires thorough EIP-712 review before it can be offered safely. |

**Practical advice:** always read the approval sheet before tapping
*Approve*, especially when a dApp interaction includes contract data. A
signature can authorize actions you do not expect, and a blockchain
transaction cannot be undone.

## Configuration

- **Add or change a network:** edit `supportedChains` in
  `lib/models/network.dart`.
- **Add or change a token:** edit the `tokens` list for that chain in the
  same file (symbol, contract address, decimals).
- **Change the default chain:** edit the initial `chain` value in
  `lib/app_state.dart` (currently BNB Chain, chosen for low-cost testing).

## Roadmap

Planned, not yet implemented — listed here so the scope of this version is
clear:

- [ ] WalletConnect support for external dApps
- [ ] EIP-712 typed-data signing, after a dedicated security review
- [ ] QR code generation and scanning for addresses
- [ ] Biometric unlock (via `local_auth`)
- [ ] Fiat price display and portfolio valuation
- [ ] Custom RPC endpoints and custom tokens from the UI
- [ ] Automated widget / integration tests and a security audit

Contributions are welcome. Please open an issue first for larger changes so
the design can be discussed before a pull request.

## Security

- This software is provided **as-is, without warranty**, under the MIT
  license. It has not been independently audited.
- Never enter your recovery phrase or private key on any website, in any
  chat, or in response to anyone claiming to be support — legitimate support
  will never ask for it.
- Verify the destination address twice before sending. Blockchain
  transactions are irreversible.
- If a device holding this wallet is lost or compromised, restore the
  recovery phrase on a new device and move funds to a fresh wallet, since
  the old phrase has existed on the compromised device.
- To report a security issue privately, please open a GitHub issue marked
  as sensitive or contact the maintainer through the repository profile
  rather than posting exploit details publicly.

## Disclaimer

EVM Wallet Lite is experimental software for managing your own
cryptocurrency. It is not a bank, exchange, or custodial service, and it is
not financial advice. You are solely responsible for backing up your keys
and for any transactions you approve. Start with small amounts, verify
everything, and do not store funds you cannot afford to lose in unaudited
software.

## License

MIT — see [LICENSE](LICENSE).
