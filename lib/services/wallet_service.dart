import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip32/bip32.dart' as bip32;
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hex/hex.dart';
import 'package:web3dart/web3dart.dart';

/// Mengelola identitas wallet: mnemonic, private key, dan PIN kunci aplikasi.
///
/// Private key TIDAK PERNAH ditulis ke file biasa / SharedPreferences.
/// Ia hanya hidup di flutter_secure_storage (Keystore/Keychain OS).
/// PIN hanya mengunci UI; kunci itu sendiri dilindungi OS.
/// Lupa PIN -> pulihkan dari mnemonic lewat layar kunci (wallet lama dihapus).
class WalletService {
  static const _kPrivateKey = 'evm_private_key';
  static const _kMnemonic = 'evm_mnemonic';
  static const _kPinHash = 'evm_pin_hash';
  static const _kPinSalt = 'evm_pin_salt';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  EthPrivateKey? _credentials;
  EthereumAddress? _address;

  bool get hasWallet => _credentials != null;
  EthPrivateKey get credentials => _credentials!;
  EthereumAddress get address => _address!;

  /// Buat wallet baru: 12 kata, derivasi BIP-44 m/44'/60'/0'/0/0.
  /// Kembalikan mnemonic-nya — pemanggil WAJIB menampilkannya sekali
  /// dan meminta pengguna mencatatnya sebelum lanjut.
  Future<String> createWallet(String pin) async {
    final mnemonic = bip39.generateMnemonic();
    await _importMnemonic(mnemonic, pin);
    return mnemonic;
  }

  Future<void> importMnemonic(String mnemonic, String pin) async {
    final words = mnemonic.trim().toLowerCase().split(RegExp(r'\s+'));
    if (words.length != 12 && words.length != 24) {
      throw ArgumentError('Mnemonic harus 12 atau 24 kata.');
    }
    if (!bip39.validateMnemonic(words.join(' '))) {
      throw ArgumentError('Mnemonic tidak valid (checksum salah).');
    }
    await _importMnemonic(words.join(' '), pin);
  }

  Future<void> importPrivateKey(String hexKey, String pin) async {
    var clean = hexKey.trim().toLowerCase();
    if (clean.startsWith('0x')) clean = clean.substring(2);
    if (clean.length != 64 || int.tryParse(clean, radix: 16) == null) {
      throw ArgumentError('Private key harus 64 karakter hex.');
    }
    await _save(EthPrivateKey.fromHex(clean), null, pin);
  }

  Future<void> _importMnemonic(String mnemonic, String pin) async {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath("m/44'/60'/0'/0/0");
    final privateKeyBytes = child.privateKey;
    if (privateKeyBytes == null) {
      throw StateError('Gagal menurunkan private key dari mnemonic.');
    }
    await _save(EthPrivateKey.fromHex(HEX.encode(privateKeyBytes)), mnemonic, pin);
  }

  Future<void> _save(
      EthPrivateKey creds, String? mnemonic, String pin) async {
    final salt = _randomHex(16);
    final pinHash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    await _storage.write(key: _kPrivateKey, value: HEX.encode(creds.privateKey));
    if (mnemonic != null) {
      await _storage.write(key: _kMnemonic, value: mnemonic);
    } else {
      await _storage.delete(key: _kMnemonic);
    }
    await _storage.write(key: _kPinSalt, value: salt);
    await _storage.write(key: _kPinHash, value: pinHash);
    _credentials = creds;
    _address = creds.address;
  }

  /// Muat wallet tersimpan (dipanggil saat aplikasi start).
  Future<bool> load() async {
    final keyHex = await _storage.read(key: _kPrivateKey);
    if (keyHex == null) return false;
    final creds = EthPrivateKey.fromHex(keyHex);
    _credentials = creds;
    _address = creds.address;
    return true;
  }

  Future<bool> get hasPin async => await _storage.read(key: _kPinHash) != null;

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _kPinSalt);
    final hash = await _storage.read(key: _kPinHash);
    if (salt == null || hash == null) return false;
    return sha256.convert(utf8.encode('$salt:$pin')).toString() == hash;
  }

  Future<String?> readMnemonic() => _storage.read(key: _kMnemonic);

  Future<void> wipe() async {
    await _storage.deleteAll();
    _credentials = null;
    _address = null;
  }

  static String _randomHex(int bytes) {
    final rnd = Random.secure();
    final data = Uint8List.fromList(
        List<int>.generate(bytes, (_) => rnd.nextInt(256)));
    return HEX.encode(data);
  }
}
