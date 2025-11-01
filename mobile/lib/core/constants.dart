import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// Permite sobrescrever o host via --dart-define=BACKEND_HOST=http://...
const String _hostDefine = String.fromEnvironment('BACKEND_HOST', defaultValue: '');

// Valores padrão (fallbacks) quando BACKEND_HOST não está definido
const String _hostWeb = 'http://127.0.0.1:8000';
// IP local do computador (para celular físico)
const String _hostLan = 'http://192.168.10.122:8000';
// IP do host quando está rodando em emulador Android
const String _hostAndroidEmu = 'http://192.168.10.122:8000';

String get backendHost {
  // Se BACKEND_HOST foi passado via dart-define, usar diretamente.
  if (_hostDefine.isNotEmpty) return _hostDefine;

  if (kIsWeb) return _hostWeb;
  try {
    if (Platform.isAndroid) {
      // Força uso do host do emulador para Android (10.0.2.2)
      // Evita timeouts quando rodando no Android Emulator.
      const bool isEmulator = bool.fromEnvironment('IS_EMULATOR', defaultValue: true);
      return isEmulator ? _hostAndroidEmu : _hostLan;
    }
    if (Platform.isIOS) return _hostLan;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return _hostWeb;
  } catch (_) {
    return _hostLan;
  }
  return _hostLan;
}

// Google Maps API key (used for Static Maps preview). Paste your key here.
// Keep this value out of public repos if it's a production key.
const String googleMapsApiKey = 'PUT_YOUR_GOOGLE_MAPS_API_KEY_HERE';

// OAuth client IDs (mobile)
// Use the Web OAuth Client ID to obtain idToken via google_sign_in
const String googleWebClientId = 'COLOQUE_SUA_WEB_CLIENT_ID_DO_GOOGLE_AQUI';