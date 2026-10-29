import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final address = state.wallet.address.hex;
    return Scaffold(
      appBar: AppBar(title: const Text('Terima')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Jaringan aktif: ${state.chain.name}'),
            const SizedBox(height: 8),
            const Text(
              'Kirim hanya aset dari jaringan yang sama ke alamat ini. '
              'Mengirim dari jaringan lain bisa membuat aset hilang.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 20),
            SelectableText(address, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: address));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alamat disalin')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Salin Alamat'),
            ),
          ],
        ),
      ),
    );
  }
}
