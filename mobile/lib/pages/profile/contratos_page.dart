import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'contrato_detalhe_page.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;
import '../../core/services/auth_service.dart';
import '../../core/constants.dart';
import '../../core/utils/url_launcher_service.dart';
import '../../core/utils/download_service.dart';

class ContratoItem {
  final int id;
  final int? imovelId;
  final String tituloImovel;
  final String solicitanteNome;
  final String cpf;
  final String telefone;
  final String? comprovanteUrl;
  final bool isOwner;
  String status;
  ContratoItem({required this.id, this.imovelId, required this.tituloImovel, required this.solicitanteNome, required this.cpf, required this.telefone, this.comprovanteUrl, required this.status, required this.isOwner});
}

class ContratosPage extends StatefulWidget {
  const ContratosPage({super.key});

  @override
  State<ContratosPage> createState() => _ContratosPageState();
}

class _ContratosPageState extends State<ContratosPage> {
  bool _loading = true;
  List<ContratoItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = await AuthService.getSavedToken();
    if (token == null) {
      setState(() => _loading = false);
      return;
    }

    // fetch current user (to check if this user is the owner of the imovel)
    Map<String, dynamic>? meUser;
    try {
      meUser = await AuthService.me(token: token);
    } catch (_) {
      meUser = null;
    }
    final currentUserId = meUser != null ? (meUser['id'] is int ? meUser['id'] as int : int.tryParse(meUser['id']?.toString() ?? '')) : null;

    final url = Uri.parse('$backendHost/propriedades/contratos/');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as List<dynamic>;
      final list = data.map<ContratoItem>((m) {
        // imovel can be an object or an id
        final imovelField = m['imovel'];
        String imovelTitulo = '';
        int? imovelId;
        if (imovelField is Map) {
          imovelTitulo = (imovelField['titulo']?.toString() ?? '');
          imovelId = (imovelField['id'] is int) ? imovelField['id'] as int : int.tryParse(imovelField['id']?.toString() ?? '');
        } else if (imovelField is int) {
          imovelId = imovelField;
        } else if (imovelField != null) {
          imovelId = int.tryParse(imovelField.toString());
        }

        final solicitante = m['solicitante'] as Map<String, dynamic>?;

        // comprovante can be a string or object depending on serializer
        String? comprov;
        final comprovField = m['comprovante'];
        if (comprovField == null) {
          comprov = null;
        } else if (comprovField is Map) {
          // look for common keys
          comprov = (comprovField['url'] ?? comprovField['comprovante'] ?? comprovField['file'] ?? comprovField['name'])?.toString();
        } else {
          comprov = comprovField.toString();
        }

        if (comprov != null && comprov.isNotEmpty && !comprov.startsWith('http')) {
          // make sure we join correctly
          if (comprov.startsWith('/')) {
            comprov = '$backendHost$comprov';
          } else {
            comprov = '$backendHost/$comprov';
          }
        }

        // determine if current user is owner of the property
        bool isOwner = false;
        try {
          if (imovelField is Map) {
            final proprietario = imovelField['proprietario'];
            if (proprietario is Map) {
              final pid = (proprietario['id'] is int) ? proprietario['id'] as int : int.tryParse(proprietario['id']?.toString() ?? '');
              if (pid != null && currentUserId != null && pid == currentUserId) isOwner = true;
            }
          }
        } catch (_) {
          isOwner = false;
        }

        return ContratoItem(
          id: m['id'] as int,
          imovelId: imovelId,
          tituloImovel: imovelTitulo,
          solicitanteNome: solicitante != null ? (solicitante['nome_completo'] ?? solicitante['username'] ?? '') : (m['nome_completo'] ?? ''),
          cpf: m['cpf']?.toString() ?? '',
          telefone: m['telefone']?.toString() ?? '',
          comprovanteUrl: (comprov == null || comprov.isEmpty) ? null : comprov,
          status: m['status']?.toString() ?? 'pending',
          isOwner: isOwner,
        );
      }).toList();
      setState(() {
        _items = list;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  String _fileNameFromUrl(String? url, String fallback) {
    if (url == null) return fallback;
    final s = url.toString();
    if (s.trim().isEmpty) return fallback;
    try {
      final uri = Uri.parse(s);
      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last;
        if (last.isNotEmpty) return last;
      }
    } catch (_) {}
    final parts = s.split('/');
    for (var i = parts.length - 1; i >= 0; i--) {
      if (parts[i].trim().isNotEmpty) return parts[i];
    }
    return fallback;
  }

  Future<void> _setStatus(int id, String status) async {
    final token = await AuthService.getSavedToken();
    if (token == null) return;
    final url = Uri.parse('$backendHost/propriedades/contratos/$id/set_status/');
    final resp = await http.post(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'status': status}));
    if (resp.statusCode == 200) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao atualizar status')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meus contratos', style: GoogleFonts.lato()),
        backgroundColor: const Color(0xFF6E56CF),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('Nenhum contrato encontrado'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final it = _items[i];
                        return InkWell(
                          onTap: () {
                            // open details page
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ContratoDetalhePage(contratoId: it.id)));
                          },
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.tituloImovel.isNotEmpty ? it.tituloImovel : (it.imovelId != null ? 'Imóvel #${it.imovelId}' : 'Imóvel não informado'),
                                  style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Row(children: [Text('Solicitante: ${it.solicitanteNome}'), const Spacer(), Text(it.status)]),
                                const SizedBox(height: 6),
                                Text('CPF: ${it.cpf}'),
                                Text('Telefone: ${it.telefone}'),
                                if (it.comprovanteUrl != null) ...[
                                  const SizedBox(height: 8),
                                  Builder(builder: (ctx) {
                                    final url = it.comprovanteUrl!;
                                    final lower = url.toLowerCase();
                                    final isImage = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.gif');
                                    // Use a full-width clickable tile for better UX — tap anywhere on the tile to open preview
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (isImage)
                                          InkWell(
                                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ComprovantePreview(url: url))),
                                            borderRadius: BorderRadius.circular(8),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(url, width: double.infinity, height: 140, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                                            ),
                                          )
                                        else
                                          Card(
                                            color: const Color(0xFFF7F7FB),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              leading: const Icon(Icons.insert_drive_file, size: 28),
                                              title: Text(_fileNameFromUrl(url, 'Abrir comprovante')),
                                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ComprovantePreview(url: url))),
                                              trailing: PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert),
                                                onSelected: (value) {
                                                  if (value == 'open') {
                                                    DownloadService.downloadAndOpen(context, url);
                                                  } else if (value == 'browser' || value == 'download') {
                                                    UrlLauncherService.openUrlExternal(ctx, url);
                                                  }
                                                },
                                                itemBuilder: (ctx2) => [
                                                  const PopupMenuItem(value: 'open', child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Abrir (baixar e abrir)'))),
                                                  const PopupMenuItem(value: 'browser', child: ListTile(leading: Icon(Icons.open_in_browser), title: Text('Abrir no navegador'))),
                                                  const PopupMenuItem(value: 'download', child: ListTile(leading: Icon(Icons.download_rounded), title: Text('Baixar'))),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  }),
                                ],
                                const SizedBox(height: 8),
                                if (it.isOwner)
                                  Row(
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                        onPressed: it.status == 'approved' ? null : () => _setStatus(it.id, 'approved'),
                                        child: const Text('Marcar viável'),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                        onPressed: it.status == 'rejected' ? null : () => _setStatus(it.id, 'rejected'),
                                        child: const Text('Marcar não viável'),
                                      ),
                                    ],
                                  )
                                else
                                  // solicitante (ou outros) apenas veem o status
                                  Text('Status: ${it.status}', style: const TextStyle(fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        ),
                      );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _ComprovantePreview extends StatefulWidget {
  final String url;
  const _ComprovantePreview({required this.url});

  @override
  State<_ComprovantePreview> createState() => _ComprovantePreviewState();
}

class _ComprovantePreviewState extends State<_ComprovantePreview> {
  late Future<PdfDocument?> _docFuture;

  @override
  void initState() {
    super.initState();
    _docFuture = _loadIfPdf();
  }

  Future<PdfDocument?> _loadIfPdf() async {
    final url = widget.url;
    final lower = url.toLowerCase();
    if (!lower.endsWith('.pdf')) return null;

    // normalize URL
    String finalUrl = url;
    if (!finalUrl.startsWith('http')) {
      if (finalUrl.startsWith('/')) finalUrl = '$backendHost$finalUrl';
      else finalUrl = '$backendHost/$finalUrl';
    }

    try {
      final resp = await http.get(Uri.parse(finalUrl));
      if (resp.statusCode == 200) {
        return PdfDocument.openData(resp.bodyBytes);
      }
    } catch (e) {
      // ignore and fallthrough to null
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    final lower = url.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Comprovante (PDF)')),
        body: FutureBuilder<PdfDocument?>(
          future: _docFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError || snap.data == null) {
              return _fallbackView(context, url);
            }
            final doc = snap.data!;
            final controller = PdfControllerPinch(document: Future.value(doc));
            return PdfViewPinch(controller: controller);
          },
        ),
      );
    }

    // fallback to image network (or url text)
    return Scaffold(
      appBar: AppBar(title: const Text('Comprovante')),
      body: Center(child: Image.network(url, errorBuilder: (_, __, ___) => _fallbackView(context, url))),
    );
  }

  Widget _fallbackView(BuildContext context, String url) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
          const SizedBox(height: 10),
          const Text('Arquivo não pode ser exibido aqui.'),
          const SizedBox(height: 8),
          SelectableText(url, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copiar link'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado')));
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir no navegador'),
            onPressed: () => UrlLauncherService.openUrlExternal(context, url),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new_outlined),
            label: const Text('Abrir (baixar e abrir)'),
            onPressed: () => DownloadService.downloadAndOpen(context, url),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded),
            label: const Text('Baixar (abrir no navegador)'),
            onPressed: () => UrlLauncherService.openUrlExternal(context, url),
          ),
        ],
      ),
    );
  }
}
