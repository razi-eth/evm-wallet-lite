import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/web3dart.dart';

import 'models/network.dart';
import 'services/rpc_service.dart';
import 'services/wallet_service.dart';

class TokenBalance {
  const TokenBalance({required this.token, required this.raw});
  final TokenInfo token;
  final BigInt raw;
}

class TxRecord {
  const TxRecord({
    required this.hash,
    required this.chainName,
    required this.to,
    required this.amount,
    required this.symbol,
  });

  final String hash;
  final String chainName;
  final String to;
  final String amount;
  final String symbol;

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'chainName': chainName,
        'to': to,
        'amount': amount,
        'symbol': symbol,
      };

  factory TxRecord.fromJson(Map<String, dynamic> json) => TxRecord(
        hash: json['hash'] as String,
        chainName: json['chainName'] as String,
        to: json['to'] as String,
        amount: json['amount'] as String,
        symbol: json['symbol'] as String,
      );
}

/// Satu-satunya state global. Sengaja pakai ChangeNotifier bawaan Flutter,
/// tanpa package state management tambahan, supaya bundle tetap ringan.
class AppState extends ChangeNotifier {
  final WalletService wallet = WalletService();
  final RpcService rpc = RpcService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Chain chain = supportedChains[1]; // Default: BNB Chain (murah untuk coba).
  BigInt nativeBalance = BigInt.zero;
  List<TokenBalance> tokenBalances = [];
  List<TxRecord> history = [];
  bool loadingBalances = false;
  String? balanceError;

  /// Origin dApp yang sudah diizinkan di sesi ini (eth_requestAccounts).
  final Set<String> connectedOrigins = {};

  Future<void> init() async {
    await wallet.load();
    await _loadHistory();
    if (wallet.hasWallet) await refreshBalances();
  }

  Future<void> setChain(Chain next) async {
    chain = next;
    notifyListeners();
    await refreshBalances();
  }

  Future<void> refreshBalances() async {
    if (!wallet.hasWallet) return;
    loadingBalances = true;
    balanceError = null;
    notifyListeners();
    try {
      nativeBalance = await rpc.nativeBalance(chain, wallet.address);
      final balances = <TokenBalance>[];
      for (final token in chain.tokens) {
        try {
          final raw = await rpc.tokenBalance(chain, token, wallet.address);
          balances.add(TokenBalance(token: token, raw: raw));
        } catch (_) {
          // Satu token gagal tidak boleh menggagalkan seluruh saldo.
        }
      }
      tokenBalances = balances;
    } catch (e) {
      balanceError = 'Gagal memuat saldo: $e';
    } finally {
      loadingBalances = false;
      notifyListeners();
    }
  }

  Future<String> sendNative(EthereumAddress to, BigInt valueWei) async {
    final hash = await rpc.sendNative(
      chain: chain,
      credentials: wallet.credentials,
      to: to,
      valueWei: valueWei,
    );
    await _addHistory(TxRecord(
      hash: hash,
      chainName: chain.name,
      to: to.hex,
      amount: formatAmount(valueWei, 18),
      symbol: chain.symbol,
    ));
    await refreshBalances();
    return hash;
  }

  Future<String> sendToken(
      TokenInfo token, EthereumAddress to, BigInt amount) async {
    final hash = await rpc.sendToken(
      chain: chain,
      credentials: wallet.credentials,
      token: token,
      to: to,
      amount: amount,
    );
    await _addHistory(TxRecord(
      hash: hash,
      chainName: chain.name,
      to: to.hex,
      amount: formatAmount(amount, token.decimals),
      symbol: token.symbol,
    ));
    await refreshBalances();
    return hash;
  }

  Future<void> _addHistory(TxRecord record) async {
    history = [record, ...history].take(50).toList();
    await _storage.write(
      key: 'evm_tx_history',
      value: jsonEncode(history.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final raw = await _storage.read(key: 'evm_tx_history');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      history = list
          .map((e) => TxRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      history = [];
    }
  }
}
