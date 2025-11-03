import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'auth_service.dart';

/// Serviço HTTP de mensagens.
/// Endpoints usados:
/// GET  /mensagens/mensagens/?with_user=<id>
/// POST /mensagens/mensagens/  { to: <id>, text: '...' }
class MessagesService {
  /// Carrega mensagens trocadas com um usuário específico.
  /// Retorna uma lista de mensagens no formato retornado pela API.
  static Future<List<Map<String, dynamic>>> loadMessagesWithUser(
    int userId, {
    String? token,
  }) async {
    final uri = Uri.parse('$backendHost/mensagens/mensagens/')
        .replace(queryParameters: {'with_user': userId.toString()});

    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final resp = await http.get(uri, headers: headers);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data.cast<Map<String, dynamic>>());
      }
      return <Map<String, dynamic>>[];
    }

    throw Exception(
        'Falha ao carregar mensagens (HTTP ${resp.statusCode}): ${resp.body}');
  }

  /// Envia uma mensagem para outro usuário.
  /// Retorna a mensagem criada (ou null em caso de erro).
  static Future<Map<String, dynamic>?> sendMessageTo(
    int toUserId,
    String text, {
    required String token,
  }) async {
    final uri = Uri.parse('$backendHost/mensagens/mensagens/');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({'to': toUserId, 'text': text});

    final resp = await http.post(uri, headers: headers, body: body);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception(
        'Falha ao enviar mensagem (HTTP ${resp.statusCode}): ${resp.body}');
  }

  /// Monitora mensagens com um usuário, fazendo polling periódico no backend.
  /// Ideal para fallback caso o WebSocket não esteja disponível.
  static Stream<List<Map<String, dynamic>>> watchWithUser(
    int userId, {
    Duration interval = const Duration(seconds: 1),
  }) {
    final controller =
        StreamController<List<Map<String, dynamic>>>.broadcast();
    Timer? timer;

    Future<void> fetchAndAdd() async {
      try {
        final token = await AuthService.getSavedToken();
        final list = await loadMessagesWithUser(userId, token: token);
        if (!controller.isClosed) controller.add(list);
      } catch (_) {
        // ignora falhas de rede para manter o polling
      }
    }

    // Executa imediatamente e depois em loop
    fetchAndAdd();
    timer = Timer.periodic(interval, (_) => fetchAndAdd());

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }
}