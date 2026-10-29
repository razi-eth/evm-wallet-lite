import 'package:flutter/material.dart';

import '../app_state.dart';

/// Kunci aplikasi dengan PIN. Lupa PIN bukan akhir dunia: dari sini
/// pengguna bisa menghapus wallet lokal dan mengimpor ulang dari mnemonic.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.state, required this.onUnlocked});
  final AppState state;
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('EVM Wallet Lite',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText(
                widget.state.wallet.address.hex,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _pin,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                onSubmitted: (_) => _unlock(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _unlock,
                child: const Text('Buka Wallet'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Hapus wallet dari perangkat?'),
                            content: const Text(
                                'Wallet lokal akan dihapus. Kamu tetap bisa '
                                'mengimpor ulang dari mnemonic / private key. '
                                'Jangan lanjutkan kalau kamu tidak punya cadangannya.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Batal')),
                              FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Hapus & Impor Ulang')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await widget.state.wallet.wipe();
                          widget.onUnlocked();
                        }
                      },
                child: const Text('Lupa PIN? Hapus & impor ulang'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.state.wallet.verifyPin(_pin.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'PIN salah.');
    }
  }
}
