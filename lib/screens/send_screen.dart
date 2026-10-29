import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';

import '../app_state.dart';
import '../models/network.dart';
import '../services/rpc_service.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key, required this.state, this.token});
  final AppState state;
  final TokenInfo? token;

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _to = TextEditingController();
  final _amount = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _success;

  bool get _isToken => widget.token != null;
  String get _symbol =>
      _isToken ? widget.token!.symbol : widget.state.chain.symbol;
  int get _decimals => _isToken ? widget.token!.decimals : 18;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kirim $_symbol')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Jaringan: ${widget.state.chain.name}'),
            const SizedBox(height: 16),
            TextField(
              controller: _to,
              decoration: const InputDecoration(
                labelText: 'Alamat tujuan (0x...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              decoration: InputDecoration(
                labelText: 'Jumlah ($_symbol)',
                border: const OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: const Text('Kirim'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_success != null) ...[
              const SizedBox(height: 12),
              SelectableText('Tx hash:\n$_success',
                  style: const TextStyle(color: Colors.green)),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 24),
            const Text(
              'Periksa alamat tujuan dua kali. Transaksi blockchain '
              'tidak bisa dibatalkan dan tidak bisa dikembalikan.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final to = EthereumAddress.fromHex(_to.text.trim());
      final amount = parseAmount(_amount.text, _decimals);
      if (amount <= BigInt.zero) throw ArgumentError('Jumlah harus > 0.');
      final hash = _isToken
          ? await widget.state.sendToken(widget.token!, to, amount)
          : await widget.state.sendNative(to, amount);
      setState(() => _success = hash);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
