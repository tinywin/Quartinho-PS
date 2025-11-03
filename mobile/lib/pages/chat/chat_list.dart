import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../core/services/auth_service.dart';
import 'chat_detail.dart';

class ChatListPage extends StatefulWidget {
  final ChatService chatService;
  final String token;

  const ChatListPage({Key? key, required this.chatService, required this.token}) : super(key: key);

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  List<dynamic> conversations = [];
  bool loading = true;
  int? _myUserId;

  @override
  void initState() {
    super.initState();
    _resolveMyUser();
    _load();
  }

  Future<void> _resolveMyUser() async {
    try {
      final me = await AuthService.me(token: widget.token);
      if (me != null) {
        setState(() => _myUserId = me['id'] is int ? me['id'] as int : int.tryParse(me['id']?.toString() ?? ''));
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await widget.chatService.fetchConversations(widget.token);
      setState(() => conversations = data);
    } catch (e) {
      // ignore for now
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mensagens')),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : conversations.isEmpty
              ? Center(child: Text('Nenhuma conversa ainda'))
              : ListView.builder(
                  itemCount: conversations.length,
                  itemBuilder: (ctx, i) {
                    final conv = conversations[i];
                    final participants = conv['participants'] as List<dynamic>;
                    
                    // Filtra para pegar o OUTRO usuário (não eu)
                    final other = participants.firstWhere(
                      (p) {
                        final pid = p['id'];
                        final participantId = pid is int ? pid : int.tryParse('$pid');
                        return participantId != _myUserId;
                      },
                      orElse: () => participants.isNotEmpty ? participants.first : null,
                    );

                    final otherName = other != null ? (other['nome'] ?? 'Usuário') : 'Sem participante';
                    final otherId = other != null ? (other['id'] is int ? other['id'] as int : int.tryParse('${other['id']}') ?? 0) : 0;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?'),
                      ),
                      title: Text(otherName),
                      subtitle: Text(conv['last_message'] ?? 'Sem mensagens'),
                      onTap: () {
                        if (otherId > 0) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatDetailPage(
                                chatService: widget.chatService,
                                token: widget.token,
                                otherUserId: otherId,
                                otherName: otherName,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
    );
  }
}
