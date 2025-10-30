// Em lib/pages/notificacoes/tela_notificacao.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// 1. IMPORTE OS SERVIÇOS NECESSÁRIOS
import '../../core/services/notification_service.dart';
import '../../core/services/auth_service.dart'; // Para pegar o token

class TelaNotificacao extends StatefulWidget {
  const TelaNotificacao({Key? key}) : super(key: key);

  @override
  State<TelaNotificacao> createState() => _TelaNotificacaoState();
}

class _TelaNotificacaoState extends State<TelaNotificacao> {
  bool _loading = true;
  List<Map<String, dynamic>> _notificacoes = [];
  String? _token; // Para armazenar o token

  @override
  void initState() {
    super.initState();
    _loadData(); // Trocamos o nome da função
  }

  // 2. CRIAMOS UMA FUNÇÃO ÚNICA PARA CARREGAR TUDO
  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Primeiro, pegamos o token salvo
    final token = await AuthService.getSavedToken();
    if (token == null) {
      // Se não tem token, não podemos carregar
      if (mounted) setState(() => _loading = false);
      // TODO: Mostrar mensagem de erro ou pedir login
      return;
    }

    _token = token; // Salva o token para uso futuro (ex: marcar como lida)
    
    // 3. CHAMADA REAL AO SERVIÇO
    await NotificationService.markAllAsRead(token: _token!);
    final res = await NotificationService.listNotifications(token: _token!);

    if (mounted) {
      setState(() {
        _notificacoes = res ?? []; // Usa a resposta ou uma lista vazia
        _loading = false;
      });
    }
  }

  // ... (a função _formatarData continua a mesma de antes) ...
  String _formatarData(String dataIso) {
    try {
      final data = DateTime.parse(dataIso).toLocal(); // .toLocal() é bom
      final agora = DateTime.now();
      final diferenca = agora.difference(data);

      if (diferenca.inDays > 1) {
        return DateFormat('dd/MM/yy \'às\' HH:mm').format(data);
      } else if (diferenca.inDays == 1 || diferenca.inHours > 20) {
        return 'Ontem às ${DateFormat('HH:mm').format(data)}';
      } else if (diferenca.inHours >= 1) {
        return 'Há ${diferenca.inHours}h';
      } else if (diferenca.inMinutes >= 1) {
        return 'Há ${diferenca.inMinutes}m';
      } else {
        return 'Agora mesmo';
      }
    } catch (e) {
      return '';
    }
  }


  // 4. ATUALIZAR O onTap (OPCIONAL, MAS RECOMENDADO)
  // Esta função será chamada quando o usuário tocar na notificação
  Future<void> _onNotificacaoTap(int index) async {
    final notificacao = _notificacoes[index];
    final bool jaEstavaLida = notificacao['lida'] ?? false;

    // Se não estava lida, marca como lida na tela
    if (!jaEstavaLida) {
      setState(() {
        _notificacoes[index]['lida'] = true;
      });
      // TODO: Chamar o NotificationService para marcar como lida no backend
      // if (_token != null) {
      //   await NotificationService.markAsRead(notificacao['id'], token: _token!);
      // }
    }

    // TODO: Adicionar navegação para o imóvel, se houver
    // if (notificacao['imovel'] != null) {
    //   // Você precisará buscar os detalhes do imóvel ou
    //   // navegar para a ImovelDetalhePage
    // }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notificacoes.isEmpty
              ? Center(
                  child: Text(
                  'Nenhuma notificação ainda',
                  style: GoogleFonts.poppins(), 
                ))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: ListView.builder(
                    itemCount: _notificacoes.length,
                    itemBuilder: (context, index) {
                      final notificacao = _notificacoes[index];
                      // 5. USAMOS OS NOMES REAIS DOS CAMPOS DO DJANGO
                      final bool lida = notificacao['lida'] ?? false;
                      final String mensagem = notificacao['mensagem'] ?? '...';
                      final String data = _formatarData(notificacao['data_criacao'] ?? '');

                      return Card(
                        elevation: 4, 
                        shadowColor: const Color(0xFF000000).withOpacity(0.05),
                        margin: const EdgeInsets.only(bottom: 12), 
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15), 
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              lida ? Icons.notifications_outlined : Icons.notifications, // Ícone muda se lida
                              color: lida ? Colors.grey : Theme.of(context).primaryColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            mensagem,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: lida ? FontWeight.normal : FontWeight.w600, 
                              color: lida ? Colors.grey[600] : Colors.black87,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              data,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          // 6. CHAMAMOS A NOVA FUNÇÃO onTap
                          onTap: () => _onNotificacaoTap(index),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}