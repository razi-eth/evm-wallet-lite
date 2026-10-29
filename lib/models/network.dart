/// Satu chain EVM. RPC di bawah adalah endpoint publik tanpa API key,
/// jadi pengguna bisa langsung pakai tanpa daftar ke provider mana pun.
class Chain {
  const Chain({
    required this.id,
    required this.name,
    required this.symbol,
    required this.rpcUrl,
    required this.explorerUrl,
    this.tokens = const [],
  });

  final int id;
  final String name;
  final String symbol;
  final String rpcUrl;
  final String explorerUrl;
  final List<TokenInfo> tokens;

  String get chainIdHex => '0x${id.toRadixString(16)}';
}

/// Token ERC-20 populer di chain tersebut. Daftar ini sengaja pendek:
/// hanya token dengan alamat kontrak yang sudah umum dipakai.
class TokenInfo {
  const TokenInfo({
    required this.symbol,
    required this.address,
    this.decimals = 18,
  });

  final String symbol;
  final String address;
  final int decimals;
}

const List<Chain> supportedChains = [
  Chain(
    id: 1,
    name: 'Ethereum',
    symbol: 'ETH',
    rpcUrl: 'https://eth.llamarpc.com',
    explorerUrl: 'https://etherscan.io',
    tokens: [
      TokenInfo(
          symbol: 'USDT',
          address: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
          decimals: 6),
      TokenInfo(
          symbol: 'USDC',
          address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
          decimals: 6),
      TokenInfo(
          symbol: 'WETH',
          address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'),
    ],
  ),
  Chain(
    id: 56,
    name: 'BNB Chain',
    symbol: 'BNB',
    rpcUrl: 'https://bsc-dataseed.binance.org',
    explorerUrl: 'https://bscscan.com',
    tokens: [
      TokenInfo(
          symbol: 'USDT',
          address: '0x55d398326f99059fF775485246999027B319F0',
          decimals: 18),
      TokenInfo(
          symbol: 'USDC',
          address: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd4',
          decimals: 18),
      TokenInfo(
          symbol: 'WBNB',
          address: '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c'),
    ],
  ),
  Chain(
    id: 137,
    name: 'Polygon',
    symbol: 'POL',
    rpcUrl: 'https://polygon-rpc.com',
    explorerUrl: 'https://polygonscan.com',
    tokens: [
      TokenInfo(
          symbol: 'USDT',
          address: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
          decimals: 6),
      TokenInfo(
          symbol: 'USDC',
          address: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
          decimals: 6),
    ],
  ),
  Chain(
    id: 42161,
    name: 'Arbitrum One',
    symbol: 'ETH',
    rpcUrl: 'https://arb1.arbitrum.io/rpc',
    explorerUrl: 'https://arbiscan.io',
    tokens: [
      TokenInfo(
          symbol: 'USDT',
          address: '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
          decimals: 6),
      TokenInfo(
          symbol: 'USDC',
          address: '0xaf88d065e77c8cC2239327C5EDb3A432268e583',
          decimals: 6),
    ],
  ),
  Chain(
    id: 8453,
    name: 'Base',
    symbol: 'ETH',
    rpcUrl: 'https://mainnet.base.org',
    explorerUrl: 'https://basescan.org',
    tokens: [
      TokenInfo(
          symbol: 'USDC',
          address: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
          decimals: 6),
    ],
  ),
  Chain(
    id: 10,
    name: 'Optimism',
    symbol: 'ETH',
    rpcUrl: 'https://mainnet.optimism.io',
    explorerUrl: 'https://optimistic.etherscan.io',
  ),
];

Chain chainById(int id) => supportedChains.firstWhere(
      (c) => c.id == id,
      orElse: () => supportedChains.first,
    );

/// ABI minimal ERC-20: cukup balanceOf, transfer, decimals.
const String erc20Abi = '''
[{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},
{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"},
{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"}]
''';
