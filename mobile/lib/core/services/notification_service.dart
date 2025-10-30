// Em lib/core/services/notification_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart'; // Para o seu 'backendHost'

class NotificationService {
  
  static Future<List<Map<String, dynamic>>?> listNotifications({
    required String token,
  }) async {
    try {
      final url = Uri.parse('$backendHost/notificacoes/'); // A URL que criamos
      
      final resp = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        // O corpo da resposta é uma Lista de objetos
        final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
        // Converte para a lista de Map que a tela espera
        return data.cast<Map<String, dynamic>>();
      } else {
        // Se falhar (ex: 401 Unauthorized), retorna null
        return null;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Erro em NotificationService.listNotifications: $e');
      return null;
    }
  }

static Future<int> getUnreadCount({ required String token }) async {
    try {
      // A nova URL que criamos no Django
      final url = Uri.parse('$backendHost/notificacoes/contagem_nao_lida/');
      
      final resp = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode == 200) {
        // Pega o JSON: {"count": 5}
        final Map<String, dynamic> data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['count'] as int; // Retorna o número
      } else {
        return 0; // Se falhar, retorna 0
      }
    } catch (e) {
      // ignore: avoid_print
      print('Erro em NotificationService.getUnreadCount: $e');
      return 0; // Se der exceção, retorna 0
    }
  }

static Future<bool> markAllAsRead({ required String token }) async {
    try {
      // A nova URL (rota) que criamos no Django
      final url = Uri.parse('$backendHost/notificacoes/marcar_todas_como_lidas/');
      
      // Usamos http.POST
      final resp = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      // 204 No Content é a resposta de sucesso que definimos
      return resp.statusCode == 204;

    } catch (e) {
      // ignore: avoid_print
      print('Erro em NotificationService.markAllAsRead: $e');
      return false; // Se der erro, retorna false
    }
  }

}