import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models/network.dart';
import '../services/rpc_service.dart';
import 'receive_screen.dart';
import 'send_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final address = state.wallet.address.hex;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Wallet'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: state.refreshBalances,
                tooltip: 'Refresh saldo',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: state.refreshBalances,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButton<Chain>(
                  value: state.chain,
                  isExpanded: true,
                  items: supportedChains
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                      .toList(),
                  onChanged: (c) {
                    if (c != null) state.setChain(c);
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(address,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: address));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Alamat disalin')),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (state.loadingBalances)
                          const CircularProgressIndicator()
                        else ...[
                          Text(
                            '${formatAmount(state.nativeBalance, 18)} ${state.chain.symbol}',
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          Text('${state.chain.name} • saldo native'),
                        ],
                        if (state.balanceError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(state.balanceError!,
                                style: const TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SendScreen(state: state)),
                        ),
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('Kirim'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ReceiveScreen(state: state)),
                        ),
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('Terima'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Token',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (state.chain.tokens.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Tidak ada token terdaftar di chain ini.'),
                  ),
                for (final b in state.tokenBalances)
                  ListTile(
                    title: Text(b.token.symbol),
                    subtitle: Text(b.token.address),
                    trailing: Text(
                        formatAmount(b.raw, b.token.decimals),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              SendScreen(state: state, token: b.token)),
                    ),
                  ),
                const SizedBox(height: 24),
                const Text('Riwayat terkirim dari wallet ini',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (state.history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Belum ada transaksi.'),
                  ),
                for (final tx in state.history)
                  ListTile(
                    title: Text('${tx.amount} ${tx.symbol}'),
                    subtitle: Text('${tx.chainName}\nKe: ${tx.to}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () {
                      // Explorer dibuka dari dApp browser agar tetap di app.
                      // Untuk sekarang, salin hash-nya.
                      Clipboard.setData(ClipboardData(text: tx.hash));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Tx hash disalin')),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
