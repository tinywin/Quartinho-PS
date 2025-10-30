import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile/core/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class AuthService {
  // Use a runtime getter so the `backendHost` selection logic (web/emulator/device)
  // is evaluated at runtime instead of trying to assign it to a compile-time const.
  static String get baseUrl => backendHost;

  static Future<bool> cadastrar({
    required String nome,
    required String email,
    required String senha,
  }) async {
    // Alinha com o backend: POST /usuarios/usercreate/
    final url = Uri.parse('$baseUrl/usuarios/usercreate/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      // O serializer espera: nome_completo, email, password
      body: jsonEncode({'nome_completo': nome, 'email': email, 'password': senha}),
    );
    return response.statusCode == 201;
  }

  /// Faz login e retorna um mapa com 'token' e opcionalmente 'user'
  /// Exemplo de retorno: {'token': '<jwt>', 'user': {...}}
  static Future<Map<String, dynamic>?> login({
    required String email,
    required String senha,
  }) async {
    final url = Uri.parse('$baseUrl/usuarios/login/');
    print('Enviando login para: ' + url.toString());
    print('Body: ' + jsonEncode({'email': email, 'password': senha}));
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': senha}),
      );
      print('Status code: ' + response.statusCode.toString());
      print('Response body: ' + response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = (data['tokens'] != null)
            ? data['tokens']['access']
            : (data['access'] ?? data['token']);
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
        }
        return {
          'token': token,
          'user': data['user'],
        };
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        // Credenciais inválidas: não lançar erro, deixar o caller tratar como login inválido
        return null;
      } else {
        // Outros erros HTTP: lançar para o caller exibir erro genérico
        throw 'Erro no login (HTTP ${response.statusCode})';
      }
    } catch (e) {
      print('Erro na requisição de login: $e');
      throw e.toString();
    }
  }

  // --- Social Login (Mobile) ---
  static Future<Map<String, dynamic>?> loginWithGoogleMobile() async {
    try {
      final google = GoogleSignIn(clientId: googleWebClientId);
      final account = await google.signIn();
      if (account == null) return null; // usuário cancelou
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw 'Google idToken indisponível. Configure o clientId (Web) no mobile.';
      }
      final url = Uri.parse('$baseUrl/usuarios/social/google/');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = (data['tokens'] != null)
            ? data['tokens']['access']
            : (data['access'] ?? data['token']);
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
        }
        return {'token': token, 'user': data['user']};
      }
      throw resp.body;
    } catch (e) {
      print('Erro login Google mobile: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> loginWithFacebookMobile() async {
    try {
      final result = await FacebookAuth.instance.login(permissions: ['email', 'public_profile']);
      if (result.status != LoginStatus.success) {
        throw result.message ?? 'Falha no login do Facebook';
      }
      final accessToken = result.accessToken?.token;
      if (accessToken == null) throw 'Facebook access_token indisponível.';
      final url = Uri.parse('$baseUrl/usuarios/social/facebook/');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': accessToken}),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = (data['tokens'] != null)
            ? data['tokens']['access']
            : (data['access'] ?? data['token']);
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
        }
        return {'token': token, 'user': data['user']};
      }
      throw resp.body;
    } catch (e) {
      print('Erro login Facebook mobile: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> me({required String token}) async {
    final url = Uri.parse('$baseUrl/usuarios/me/');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Erro ao buscar /me: $e');
      return null;
    }
  }

  /// Atualiza a preferência do usuário ("room" ou "roommate")
  static Future<bool> updatePreference({
    required String token,
    required String preferenceType,
  }) async {
    final url = Uri.parse('$baseUrl/usuarios/preferences/');
    try {
      final resp = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'preference_type': preferenceType}),
      );
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      print('Erro ao atualizar preferência: $e');
      return false;
    }
  }

  static Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  // --- Onboarding flags (persist per user email) ---
  static String _roleKey(String email) => 'role_completed_${email.toLowerCase()}';
  static String _profileKey(String email) => 'profile_completed_${email.toLowerCase()}';

  static Future<void> setRoleCompleted(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_roleKey(email), true);
  }

  static Future<void> setProfileCompleted(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_profileKey(email), true);
  }

  static Future<bool> isOnboardingCompleted(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final roleDone = prefs.getBool(_roleKey(email)) ?? false;
    final profileDone = prefs.getBool(_profileKey(email)) ?? false;
    return roleDone && profileDone;
  }
}
