import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:web3dart/web3dart.dart';

import '../app_state.dart';
import '../models/network.dart';
import '../services/dapp_bridge.dart';
import '../services/rpc_service.dart';
import '../widgets/approval_sheet.dart';

/// dApp browser: WebView + provider EIP-1193 (window.ethereum).
///
/// Aturan keamanan yang ditegakkan di sini, bukan di JavaScript:
/// 1. dApp TIDAK otomatis dapat alamat. eth_requestAccounts selalu
///    minta persetujuan, satu kali per origin per sesi.
/// 2. eth_sendTransaction & personal_sign SELALU minta persetujuan
///    lewat bottom sheet, dengan detail yang bisa dibaca.
/// 3. eth_sign mentah & eth_signTypedData ditolak di MVP ini.
/// 4. Switch chain hanya ke chain yang didukung aplikasi.
class DappScreen extends StatefulWidget {
  const DappScreen({super.key, required this.state});
  final AppState state;

  @override
  State<DappScreen> createState() => _DappScreenState();
}

class _DappScreenState extends State<DappScreen> {
  InAppWebViewController? _controller;
  final _url = TextEditingController();
  String _origin = '';
  bool _loading = false;

  static const _quickLinks = [
    ('Uniswap', 'https://app.uniswap.org'),
    ('PancakeSwap', 'https://pancakeswap.finance/swap'),
    ('OpenSea', 'https://opensea.io'),
    ('Etherscan', 'https://etherscan.io'),
    ('BscScan', 'https://bscscan.com'),
  ];

  AppState get _state => widget.state;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _load(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return;
    if (!url.contains('://')) url = 'https://$url';
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Ganti chain -> WebView dibuat ulang agar script provider
    // disuntik dengan chainId yang benar.
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('dApps'),
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _controller?.goBack(),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller?.reload(),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _url,
                      decoration: InputDecoration(
                        hintText: 'Masukkan URL dApp, mis. app.uniswap.org',
                        border: const OutlineInputBorder(),
                        suffixIcon: _loading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : null,
                      ),
                      onSubmitted: _load,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => _load(_url.text),
                    child: const Text('Buka'),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (final link in _quickLinks)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(link.$1),
                        onPressed: () {
                          _url.text = link.$2;
                          _load(link.$2);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Text('Chain: ${_state.chain.name}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  if (_origin.isNotEmpty)
                    Text(_origin,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: InAppWebView(
                key: ValueKey(_state.chain.id),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                ),
                initialUserScripts: {
                  UserScript(
                    source: evmProviderScript(_state.chain.chainIdHex),
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    forMainFrameOnly: true,
                  ),
                },
                onWebViewCreated: (controller) {
                  _controller = controller;
                  controller.addJavaScriptHandler(
                    handlerName: 'evmBridge',
                    callback: (args) => _handleBridge(controller, args),
                  );
                },
                onLoadStart: (controller, url) {
                  final uri = url;
                  if (uri != null) {
                    _origin = uri.host;
                    _url.text = uri.toString();
                    setState(() => _loading = true);
                  }
                },
                onLoadStop: (controller, url) {
                  if (mounted) setState(() => _loading = false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBridge(
      InAppWebViewController controller, List<dynamic> args) async {
    if (args.isEmpty || args.first is! String) return;
    late Map<String, dynamic> req;
    try {
      req = jsonDecode(args.first as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final id = req['id'];
    final method = req['method'] as String? ?? '';
    final params = (req['params'] as List<dynamic>?) ?? [];

    Future<void> resolve(dynamic result) => controller.evaluateJavascript(
          source: 'window.__evmResolve($id, ${jsonEncode(result)});',
        );
    Future<void> reject(String message) => controller.evaluateJavascript(
          source: 'window.__evmReject($id, ${jsonEncode(message)});',
        );

    try {
      final result = await _handleMethod(method, params);
      await resolve(result);
    } catch (e) {
      await reject('$e');
    }
  }

  /// Kembalikan nilai JSON yang dikirim balik ke dApp.
  Future<dynamic> _handleMethod(String method, List<dynamic> params) async {
    final chain = _state.chain;
    final address = _state.wallet.address.hex;

    switch (method) {
      case 'eth_requestAccounts':
        if (!_state.connectedOrigins.contains(_origin)) {
          if (!mounted) throw Exception('Ditolak pengguna.');
          final ok = await showApprovalSheet(
            context,
            title: 'Hubungkan wallet ke dApp?',
            origin: _origin,
            details: [
              MapEntry('Alamat', address),
              const MapEntry(
                  'Catatan',
                  'dApp hanya melihat alamatmu. '
                      'Transaksi & signature tetap minta persetujuan terpisah.'),
            ],
            approveLabel: 'Hubungkan',
          );
          if (!ok) throw Exception('Pengguna menolak koneksi.');
          _state.connectedOrigins.add(_origin);
          await _controller?.evaluateJavascript(
            source:
                'window.__evmSetAccounts(${jsonEncode([address])});',
          );
        }
        return [address];

      case 'eth_accounts':
        return _state.connectedOrigins.contains(_origin) ? [address] : [];

      case 'eth_chainId':
        return chain.chainIdHex;

      case 'net_version':
        return '${chain.id}';

      case 'wallet_switchEthereumChain':
      case 'wallet_addEthereumChain':
        final wanted = _parseHexInt(
            (params.first as Map<String, dynamic>)['chainId'] as String);
        final matches =
            supportedChains.where((c) => c.id == wanted).toList();
        if (matches.isEmpty) {
          throw Exception('Chain $wanted tidak didukung wallet ini.');
        }
        final next = matches.first;
        await _state.setChain(next);
        return null;

      case 'eth_sendTransaction':
        if (!_state.connectedOrigins.contains(_origin)) {
          throw Exception('Hubungkan wallet dulu (eth_requestAccounts).');
        }
        final tx = params.first as Map<String, dynamic>;
        final toHex = tx['to'] as String?;
        if (toHex == null) throw Exception('Transaksi tanpa tujuan.');
        final valueWei = tx['value'] == null
            ? BigInt.zero
            : _parseHexBigInt(tx['value'] as String);
        final dataHex = tx['data'] as String?;
        final details = <MapEntry<String, String>>[
          MapEntry('Ke', toHex),
          MapEntry('Nilai',
              '${formatAmount(valueWei, 18)} ${chain.symbol}'),
          if (dataHex != null && dataHex != '0x')
            MapEntry('Data kontrak',
                dataHex.length > 68 ? '${dataHex.substring(0, 68)}…' : dataHex),
        ];
        if (!mounted) throw Exception('Ditolak pengguna.');
        final ok = await showApprovalSheet(
          context,
          title: dataHex != null && dataHex != '0x'
              ? 'Setujui interaksi kontrak?'
              : 'Setujui pengiriman?',
          origin: _origin,
          details: details,
        );
        if (!ok) throw Exception('Pengguna menolak transaksi.');
        final hash = await _state.rpc.clientFor(chain).sendTransaction(
              _state.wallet.credentials,
              Transaction(
                to: EthereumAddress.fromHex(toHex),
                value: EtherAmount.inWei(valueWei),
                data: dataHex == null ? null : _hexToBytes(dataHex),
              ),
              chainId: chain.id,
            );
        await _state.refreshBalances();
        return hash;

      case 'personal_sign':
        if (!_state.connectedOrigins.contains(_origin)) {
          throw Exception('Hubungkan wallet dulu (eth_requestAccounts).');
        }
        final rawMessage = params.first as String;
        final messageBytes = rawMessage.startsWith('0x')
            ? _hexToBytes(rawMessage)
            : Uint8List.fromList(utf8.encode(rawMessage));
        final messageText = utf8.decode(messageBytes, allowMalformed: true);
        if (!mounted) throw Exception('Ditolak pengguna.');
        final ok = await showApprovalSheet(
          context,
          title: 'Setujui signature?',
          origin: _origin,
          details: [
            const MapEntry(
                'Peringatan',
                'Signature bisa dipakai untuk login, tapi jangan setujui '
                    'pesan yang kamu tidak mengerti isinya.'),
            MapEntry('Pesan', messageText),
          ],
        );
        if (!ok) throw Exception('Pengguna menolak signature.');
        final sig =
            await _state.wallet.credentials.signPersonalMessage(messageBytes);
        final r = sig.r.toRadixString(16).padLeft(64, '0');
        final s = sig.s.toRadixString(16).padLeft(64, '0');
        final v = sig.v.toRadixString(16).padLeft(2, '0');
        return '0x$r$s$v';

      case 'eth_sign':
      case 'eth_signTypedData':
      case 'eth_signTypedData_v3':
      case 'eth_signTypedData_v4':
        throw Exception(
            'Method $method belum didukung di versi lite ini demi keamanan.');

      default:
        // Semua method read-only diteruskan mentah ke RPC chain aktif.
        return _state.rpc.rawRpc(chain, method, params);
    }
  }

  static BigInt _parseHexBigInt(String value) {
    if (value.startsWith('0x')) {
      return BigInt.parse(value.substring(2), radix: 16);
    }
    return BigInt.parse(value);
  }

  static int _parseHexInt(String value) => _parseHexBigInt(value).toInt();

  static Uint8List _hexToBytes(String hexValue) {
    var clean = hexValue.startsWith('0x') ? hexValue.substring(2) : hexValue;
    if (clean.length.isOdd) clean = '0$clean';
    final out = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
