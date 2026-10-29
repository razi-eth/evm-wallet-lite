import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state, required this.onWiped});
  final AppState state;
  final VoidCallback onWiped;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Alamat wallet'),
            subtitle: SelectableText(state.wallet.address.hex),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => Clipboard.setData(
                  ClipboardData(text: state.wallet.address.hex)),
            ),
          ),
          ListTile(
            title: const Text('Lihat mnemonic (cadangan)'),
            subtitle: const Text(
                'Hanya tampilkan di tempat privat. Jangan pernah kirim '
                'ke orang lain / ke support manapun.'),
            trailing: const Icon(Icons.visibility),
            onTap: () async {
              final mnemonic = await state.wallet.readMnemonic();
              if (!context.mounted) return;
              if (mnemonic == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Mnemonic tidak tersimpan (wallet diimpor dari private key).')),
                );
                return;
              }
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Mnemonic kamu'),
                  content: SelectableText(mnemonic),
                  actions: [
                    TextButton(
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: mnemonic)),
                      child: const Text('Salin'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            title: const Text('dApp yang terhubung di sesi ini'),
            subtitle: Text(
              state.connectedOrigins.isEmpty
                  ? 'Belum ada.'
                  : state.connectedOrigins.join(', '),
            ),
            trailing: TextButton(
              onPressed: () {
                state.connectedOrigins.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Semua koneksi dApp diputus.')),
                );
              },
              child: const Text('Putuskan semua'),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Hapus wallet dari perangkat',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text(
                'Hanya lakukan ini kalau kamu sudah mencatat mnemonic / '
                'private key. Aset di blockchain tidak hilang, tapi akses '
                'dari perangkat ini hilang.'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus wallet?'),
                  content: const Text(
                      'Pastikan mnemonic / private key sudah dicatat.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Hapus')),
                  ],
                ),
              );
              if (confirm == true) {
                await state.wallet.wipe();
                onWiped();
              }
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'EVM Wallet Lite v0.1.0 — MVP open source, belum diaudit. '
            'Jangan simpan dana besar di wallet ini sebelum audit '
            'dan pengujian menyeluruh. Gunakan jaringan murah (BSC) '
            'untuk percobaan pertama.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
