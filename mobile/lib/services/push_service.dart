import 'dart:io';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/local_notifications.dart';
import 'package:mobile/core/navigation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/constants.dart';
import 'package:mobile/pages/imoveis/imovel_detalhe_page.dart';
import 'package:mobile/pages/imoveis/chat_page.dart';

class PushService {
  static final FirebaseMessaging _fm = FirebaseMessaging.instance;

  static Future<void> init() async {
    // Request permission on iOS
    try {
      await _fm.requestPermission();
    } catch (e) {
      // ignore
    }
    await LocalNotifications.init();
  }

  static Future<String?> getToken() async {
    try {
      return await _fm.getToken();
    } catch (e) {
      return null;
    }
  }

  static Future<bool> registerDevice({required String baseUrl, String? jwtToken}) async {
    final token = await getToken();
    if (token == null) return false;
    final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other');
    final url = Uri.parse('$baseUrl/notificacoes/register-device/');
    final headers = {'Content-Type': 'application/json'};
    if (jwtToken != null) headers['Authorization'] = 'Bearer $jwtToken';
    final body = json.encode({'token': token, 'platform': platform});
    try {
      final res = await http.post(url, headers: headers, body: body);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  // Background handler must be a top-level or static function
  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    // Minimal: show local notification so the user sees it
    final title = message.notification?.title ?? 'Nova notificação';
    final body = message.notification?.body ?? '';
    await LocalNotifications.showSimple(title: title, body: body);
  }

  static void configureListeners({required String jwtToken}) {
    // Foreground
    FirebaseMessaging.onMessage.listen((message) async {
      final title = message.notification?.title ?? 'Nova notificação';
      final body = message.notification?.body ?? '';
      await LocalNotifications.showSimple(title: title, body: body);
    });

    // When app opened by tapping notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNavigationFromData(message.data);
    });

    // Token refresh -> re-register device
    _fm.onTokenRefresh.listen((newToken) async {
      try {
        await registerDevice(baseUrl: backendHost, jwtToken: jwtToken);
      } catch (_) {}
    });
  }

  static Future<void> _handleNavigationFromData(Map<String, dynamic> data) async {
    try {
      final type = data['type']?.toString();
      if (type == 'chat' || data.containsKey('from_user')) {
        final otherId = int.tryParse((data['from_user'] ?? data['sender'] ?? '').toString());
        if (otherId != null) {
          final name = data['from_name']?.toString() ?? 'Contato';
          rootNavigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => ChatPage(ownerId: otherId, ownerName: name)),
          );
          return;
        }
      }
      if (data.containsKey('imovel')) {
        final id = int.tryParse(data['imovel'].toString());
        if (id != null) {
          // fetch lightweight imovel payload
          final url = Uri.parse('$backendHost/propriedades/propriedades/$id/');
          try {
            final resp = await http.get(url);
            if (resp.statusCode == 200) {
              final map = json.decode(resp.body) as Map<String, dynamic>;
              rootNavigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => ImovelDetalhePage(imovel: map)),
              );
              return;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
