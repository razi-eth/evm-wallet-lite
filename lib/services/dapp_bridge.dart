/// Provider EIP-1193 yang disuntikkan ke setiap dApp yang dibuka di
/// dApp browser. dApp memanggil `window.ethereum.request(...)` seperti
/// biasa; bridge ini meneruskannya ke Dart lewat JavaScript handler
/// `evmBridge`, dan Dart membalas lewat `window.__evmResolve/__evmReject`.
///
/// Yang ditangani di Dart (lihat dapp_screen.dart):
/// - eth_requestAccounts / eth_accounts  -> alamat wallet (setelah dApp
///   diizinkan sekali per sesi oleh pengguna)
/// - eth_chainId / net_version           -> chain aktif
/// - eth_sendTransaction / personal_sign -> SELALU minta persetujuan
///   pengguna lewat bottom sheet sebelum signing
/// - eth_switchEthereumChain             -> hanya chain yang didukung app
/// - method read-only lainnya            -> diteruskan mentah ke RPC
String evmProviderScript(String chainIdHex) {
  return '''
(function() {
  if (window.ethereum && window.ethereum.__evmLite) return;
  var callbacks = {};
  var nextId = 1;
  var listeners = {};
  function emit(event, data) {
    var list = listeners[event] || [];
    for (var i = 0; i < list.length; i++) { try { list[i](data); } catch (e) {} }
  }
  window.__evmResolve = function(id, result) {
    var cb = callbacks[id];
    if (cb) { delete callbacks[id]; cb.resolve(result); }
  };
  window.__evmReject = function(id, message) {
    var cb = callbacks[id];
    if (cb) { delete callbacks[id]; cb.reject(new Error(message)); }
  };
  window.__evmSetChainId = function(chainId) {
    window.ethereum.chainId = chainId;
    emit('chainChanged', chainId);
  };
  window.__evmSetAccounts = function(accounts) {
    emit('accountsChanged', accounts);
  };
  var provider = {
    __evmLite: true,
    isMetaMask: true,
    chainId: '$chainIdHex',
    selectedAddress: null,
    request: function(args) {
      return new Promise(function(resolve, reject) {
        var id = nextId++;
        callbacks[id] = { resolve: resolve, reject: reject };
        var payload = JSON.stringify({ id: id, method: args.method, params: args.params || [] });
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('evmBridge', payload);
        } else {
          reject(new Error('Bridge tidak tersedia'));
        }
      });
    },
    send: function(method, params) { return this.request({ method: method, params: params }); },
    on: function(event, fn) {
      if (!listeners[event]) listeners[event] = [];
      listeners[event].push(fn);
    },
    removeListener: function(event, fn) {
      var list = listeners[event] || [];
      var idx = list.indexOf(fn);
      if (idx >= 0) list.splice(idx, 1);
    }
  };
  window.ethereum = provider;
  window.web3 = { currentProvider: provider };
})();
''';
}
