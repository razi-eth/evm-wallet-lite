import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/dapp_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const EvmWalletLiteApp());
}

class EvmWalletLiteApp extends StatefulWidget {
  const EvmWalletLiteApp({super.key});

  @override
  State<EvmWalletLiteApp> createState() => _EvmWalletLiteAppState();
}

class _EvmWalletLiteAppState extends State<EvmWalletLiteApp> {
  final AppState _state = AppState();
  bool _initialized = false;
  bool _unlocked = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _state.init();
    if (mounted) setState(() => _initialized = true);
  }

  /// Setelah wipe / lupa PIN, kembali ke onboarding.
  void _reset() {
    setState(() {
      _unlocked = false;
      _tab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EVM Wallet Lite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) {
          if (!_initialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!_state.wallet.hasWallet) {
            return OnboardingScreen(
              state: _state,
              onWalletReady: () => setState(() => _unlocked = true),
            );
          }
          if (!_unlocked) {
            return LockScreen(
              state: _state,
              onUnlocked: () {
                // Kalau wallet di-wipe dari lock screen, hasWallet false
                // -> Builder di atas akan menampilkan onboarding lagi.
                setState(() => _unlocked = true);
              },
            );
          }
          return Scaffold(
            body: IndexedStack(
              index: _tab,
              children: [
                HomeScreen(state: _state),
                DappScreen(state: _state),
                SettingsScreen(state: _state, onWiped: _reset),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.account_balance_wallet),
                    label: 'Wallet'),
                NavigationDestination(
                    icon: Icon(Icons.apps), label: 'dApps'),
                NavigationDestination(
                    icon: Icon(Icons.settings), label: 'Pengaturan'),
              ],
            ),
          );
        },
      ),
    );
  }
}
