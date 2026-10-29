import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';

/// Layar pertama: buat wallet baru, atau impor dari mnemonic / private key.
/// Mnemonic baru ditampilkan SEKALI dan harus dicatat sebelum lanjut.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state, required this.onWalletReady});
  final AppState state;
  final VoidCallback onWalletReady;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _input = TextEditingController();
  final _pin = TextEditingController();
  String? _mnemonic;
  bool _busy = false;
  String? _error;
  bool _importPrivateKey = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EVM Wallet Lite')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Wallet EVM ringan.\nBuat baru, atau impor wallet yang sudah ada.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pin,
              decoration: const InputDecoration(
                labelText: 'PIN aplikasi (6 digit)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
            const SizedBox(height: 12),
            if (_mnemonic == null) ...[
              FilledButton(
                onPressed: _busy || _pin.text.length < 4
                    ? null
                    : () => _run(() async {
                          final m =
                              await widget.state.wallet.createWallet(_pin.text);
                          setState(() => _mnemonic = m);
                          await widget.state.refreshBalances();
                        }),
                child: const Text('Buat Wallet Baru'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Mnemonic'),
                    selected: !_importPrivateKey,
                    onSelected: (_) =>
                        setState(() => _importPrivateKey = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Private Key'),
                    selected: _importPrivateKey,
                    onSelected: (_) =>
                        setState(() => _importPrivateKey = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _input,
                decoration: InputDecoration(
                  labelText: _importPrivateKey
                      ? 'Private key (hex, 0x boleh)'
                      : 'Mnemonic (12 / 24 kata, pisahkan spasi)',
                  border: const OutlineInputBorder(),
                ),
                maxLines: _importPrivateKey ? 1 : 3,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy || _pin.text.length < 4 || _input.text.isEmpty
                    ? null
                    : () => _run(() async {
                          if (_importPrivateKey) {
                            await widget.state.wallet
                                .importPrivateKey(_input.text, _pin.text);
                          } else {
                            await widget.state.wallet
                                .importMnemonic(_input.text, _pin.text);
                          }
                          await widget.state.refreshBalances();
                          widget.onWalletReady();
                        }),
                child: const Text('Impor Wallet'),
              ),
            ] else ...[
              const Text(
                'CATAT 12 KATA INI DI TEMPAT AMAN. '
                'Siapa pun yang punya kata-kata ini bisa mengambil seluruh asetmu. '
                'Aplikasi tidak menyimpannya di server mana pun.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(_mnemonic!, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Clipboard.setData(
                    ClipboardData(text: _mnemonic!)),
                icon: const Icon(Icons.copy),
                label: const Text('Salin mnemonic'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: widget.onWalletReady,
                child: const Text('Saya sudah mencatatnya, lanjut'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
