import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

import '../models/network.dart';

/// Lapisan RPC per chain. Satu Web3Client dibuat per chain dan dipakai ulang,
/// supaya tidak membuka koneksi baru setiap kali cek saldo.
class RpcService {
  final Map<int, Web3Client> _clients = {};
  final http.Client _http = http.Client();

  Web3Client clientFor(Chain chain) {
    return _clients.putIfAbsent(
      chain.id,
      () => Web3Client(chain.rpcUrl, _http),
    );
  }

  Future<BigInt> nativeBalance(Chain chain, EthereumAddress address) async {
    final balance = await clientFor(chain).getBalance(address);
    return balance.getInWei;
  }

  Future<BigInt> tokenBalance(
      Chain chain, TokenInfo token, EthereumAddress owner) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(erc20Abi, 'ERC20'),
      EthereumAddress.fromHex(token.address),
    );
    final result = await clientFor(chain).call(
      contract: contract,
      function: contract.function('balanceOf'),
      params: [owner],
    );
    return result.first as BigInt;
  }

  /// Kirim native coin. Kembalikan tx hash.
  Future<String> sendNative({
    required Chain chain,
    required Credentials credentials,
    required EthereumAddress to,
    required BigInt valueWei,
  }) async {
    return clientFor(chain).sendTransaction(
      credentials,
      Transaction(to: to, value: EtherAmount.inWei(valueWei)),
      chainId: chain.id,
    );
  }

  /// Kirim token ERC-20 via transfer(). Kembalikan tx hash.
  Future<String> sendToken({
    required Chain chain,
    required Credentials credentials,
    required TokenInfo token,
    required EthereumAddress to,
    required BigInt amount,
  }) async {
    final contract = DeployedContract(
      ContractAbi.fromJson(erc20Abi, 'ERC20'),
      EthereumAddress.fromHex(token.address),
    );
    return clientFor(chain).sendTransaction(
      credentials,
      Transaction.callContract(
        contract: contract,
        function: contract.function('transfer'),
        parameters: [to, amount],
      ),
      chainId: chain.id,
    );
  }

  /// JSON-RPC mentah untuk dApp browser: semua method read-only
  /// (eth_call, eth_getBalance, eth_blockNumber, dsb) diteruskan ke RPC
  /// chain aktif tanpa lewat signing.
  Future<dynamic> rawRpc(Chain chain, String method, List<dynamic> params) async {
    final res = await _http.post(
      Uri.parse(chain.rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('RPC error ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      throw Exception('${body['error']}');
    }
    return body['result'];
  }

  void dispose() {
    for (final c in _clients.values) {
      c.dispose();
    }
    _http.close();
  }
}

/// Format saldo BigInt -> string yang enak dibaca, mis. 1.2345.
String formatAmount(BigInt raw, int decimals, {int maxFraction = 6}) {
  if (raw == BigInt.zero) return '0';
  final divisor = BigInt.from(10).pow(decimals);
  final whole = raw ~/ divisor;
  var frac = (raw % divisor).toString().padLeft(decimals, '0');
  frac = frac.replaceAll(RegExp(r'0+$'), '');
  if (frac.length > maxFraction) frac = frac.substring(0, maxFraction);
  return frac.isEmpty ? '$whole' : '$whole.$frac';
}

/// Parse input pengguna ("1.5") -> wei / unit terkecil token.
BigInt parseAmount(String input, int decimals) {
  final clean = input.trim().replaceAll(',', '.');
  final parts = clean.split('.');
  if (parts.length > 2) throw FormatException('Jumlah tidak valid.');
  final whole = BigInt.parse(parts[0].isEmpty ? '0' : parts[0]);
  var frac = parts.length == 2 ? parts[1] : '';
  if (frac.length > decimals) frac = frac.substring(0, decimals);
  final fracValue =
      frac.isEmpty ? BigInt.zero : BigInt.parse(frac.padRight(decimals, '0'));
  return whole * BigInt.from(10).pow(decimals) + fracValue;
}
