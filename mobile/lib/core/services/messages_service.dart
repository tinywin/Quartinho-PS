import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'auth_service.dart';

/// HTTP-backed messages service. Calls the backend endpoints:
/// GET  /mensagens/mensagens/?with_user=<id>
/// POST /mensagens/mensagens/  { to: <id>, text: '...' }
class MessagesService {
  /// Load messages with a specific user (requires authentication to see
  /// private messages). Returns a list of message maps as returned by the API.
  static Future<List<Map<String, dynamic>>> loadMessagesWithUser(int userId, {String? token}) async {
  // backend exposes the mensagens endpoint at /mensagens/ (see backend/mensagens/urls.py)
  final uri = Uri.parse('$backendHost/mensagens/').replace(queryParameters: {'with_user': userId.toString()});
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body);
      if (data is List) return List<Map<String, dynamic>>.from(data.cast<Map<String, dynamic>>());
      return <Map<String, dynamic>>[];
    }
    return <Map<String, dynamic>>[];
  }

  /// Send a message to a user. Returns the created message (or null on failure).
  static Future<Map<String, dynamic>?> sendMessageTo(int toUserId, String text, {required String token}) async {
  final uri = Uri.parse('$backendHost/mensagens/');
    final headers = {'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer $token'};
    final body = jsonEncode({'to': toUserId, 'text': text});
    final resp = await http.post(uri, headers: headers, body: body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    return null;
  }

  /// Watch messages with user by polling the backend periodically.
  static Stream<List<Map<String, dynamic>>> watchWithUser(int userId, {Duration interval = const Duration(milliseconds: 800)}) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    Timer? timer;

    Future<void> fetchAndAdd() async {
      final token = await AuthService.getSavedToken();
      final list = await loadMessagesWithUser(userId, token: token);
      if (!controller.isClosed) controller.add(list);
    }

    // Start immediately
    fetchAndAdd();
    timer = Timer.periodic(interval, (_) => fetchAndAdd());

    controller.onCancel = () {
      timer?.cancel();
      controller.close();
    };

    return controller.stream;
  }
}
