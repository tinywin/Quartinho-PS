import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:flutter/services.dart';
import 'package:http_parser/http_parser.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants.dart';
import '../../core/utils/url_launcher_service.dart';
import '../../core/utils/download_service.dart';
import '../payments/pagamento_page.dart';

class ContratoDetalhePage extends StatefulWidget {
  final int contratoId;
  const ContratoDetalhePage({super.key, required this.contratoId});

  @override
  State<ContratoDetalhePage> createState() => _ContratoDetalhePageState();
}

class _ContratoDetalhePageState extends State<ContratoDetalhePage> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  PlatformFile? _pickedFile;
  PlatformFile? _pickedFileSigned;
  int? _currentUserId;
  bool _isOwner = false;
  bool _isSolicitante = false;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = await AuthService.getSavedToken();
    if (token == null) return setState(() => _loading = false);
    final url = Uri.parse('$backendHost/propriedades/contratos/${widget.contratoId}/');
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode == 200) {
      _data = jsonDecode(resp.body) as Map<String, dynamic>;
      try {
        final me = await AuthService.me(token: token);
        if (me != null && me['id'] != null) {
          _currentUserId = me['id'] as int;
        }
      } catch (e) {
        print('ContratoDetalhePage: erro ao obter usuário atual: $e');
      }

      // determine roles: owner vs solicitante
      int? ownerId;
      try {
        final imovel = _data?['imovel'];
        if (imovel is Map) {
          final proprietario = imovel['proprietario'];
          if (proprietario is Map && proprietario['id'] != null) ownerId = proprietario['id'] as int;
          else if (proprietario is int) ownerId = proprietario;
        }
      } catch (_) {}

      int? solicitanteId;
      try {
        final solicitante = _data?['solicitante'];
        if (solicitante is Map && solicitante['id'] != null) solicitanteId = solicitante['id'] as int;
        else if (solicitante is int) solicitanteId = solicitante;
      } catch (_) {}

      _isOwner = (_currentUserId != null && ownerId != null && _currentUserId == ownerId);
      _isSolicitante = (_currentUserId != null && solicitanteId != null && _currentUserId == solicitanteId);
    }
    setState(() => _loading = false);
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
    // last resort: split by / and return last non-empty
    final parts = s.split('/');
    for (var i = parts.length - 1; i >= 0; i--) {
      if (parts[i].trim().isNotEmpty) return parts[i];
    }
    return fallback;
  }

  Future<void> _pickFile() async {
    try {
      // ask for bytes explicitly so we can upload without relying on file path availability
      final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (res == null) {
        // user cancelled — no action
        return;
      }
      if (res.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum arquivo selecionado')));
        return;
      }
      final f = res.files.first;
      // debug print
      try {
        print('ContratoDetalhePage: picked file name=${f.name} size=${f.size} bytes=${f.bytes != null} path=${f.path}');
      } catch (_) {}
      setState(() => _pickedFile = f);
    } catch (e) {
      // show helpful message to the user and print to console for debugging
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir seletor de arquivos: $e')));
      print('Erro FilePicker.pickFiles: $e');
    }
  }

  Future<void> _pickImageFallback() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? xfile = await picker.pickImage(source: ImageSource.gallery);
      if (xfile == null) return; // canceled
      final bytes = await xfile.readAsBytes();
      final pf = PlatformFile(name: xfile.name, size: bytes.length, bytes: bytes, path: xfile.path);
      print('ContratoDetalhePage: fallback picked image name=${pf.name} size=${pf.size} path=${pf.path}');
      setState(() => _pickedFile = pf);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir galeria: $e')));
      print('Erro ImagePicker.pickImage: $e');
    }
  }

  // Pickers for the signed contract (solicitante)
  Future<void> _pickFileAssinado() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (res == null) return;
      if (res.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum arquivo selecionado')));
        return;
      }
      final f = res.files.first;
      try {
        print('ContratoDetalhePage: picked signed file name=${f.name} size=${f.size} bytes=${f.bytes != null} path=${f.path}');
      } catch (_) {}
      setState(() => _pickedFileSigned = f);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir seletor de arquivos: $e')));
      print('Erro FilePicker.pickFiles (signed): $e');
    }
  }

  Future<void> _pickImageFallbackAssinado() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? xfile = await picker.pickImage(source: ImageSource.gallery);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final pf = PlatformFile(name: xfile.name, size: bytes.length, bytes: bytes, path: xfile.path);
      print('ContratoDetalhePage: fallback picked signed image name=${pf.name} size=${pf.size} path=${pf.path}');
      setState(() => _pickedFileSigned = pf);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir galeria: $e')));
      print('Erro ImagePicker.pickImage (signed): $e');
    }
  }

  void _showPickOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Escolher arquivo (PDF, doc, etc.)'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher imagem (galeria)'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImageFallback();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancelar'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickOptionsAssinado() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Escolher arquivo (PDF, doc, etc.)'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickFileAssinado();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher imagem (galeria)'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImageFallbackAssinado();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancelar'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um arquivo primeiro')));
      return;
    }
    final token = await AuthService.getSavedToken();
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final uri = Uri.parse('$backendHost/propriedades/contratos/${widget.contratoId}/upload_contrato/');
      final req = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $token';

      // prefer fromPath when path is available (more reliable for large files on Android),
      // otherwise use bytes. Also set a sensible Content-Type based on extension.
      final name = _pickedFile!.name;
      final path = _pickedFile!.path;
      String ext = '';
      if (name.contains('.')) ext = name.split('.').last.toLowerCase();
      MediaType? mediaType;
      if (ext == 'pdf') mediaType = MediaType('application', 'pdf');
      else if (ext == 'png') mediaType = MediaType('image', 'png');
      else if (ext == 'jpg' || ext == 'jpeg') mediaType = MediaType('image', 'jpeg');
      else if (ext == 'gif') mediaType = MediaType('image', 'gif');
      else mediaType = MediaType('application', 'octet-stream');

      http.MultipartFile multipartFile;
      if (path != null && path.isNotEmpty) {
        try {
          multipartFile = await http.MultipartFile.fromPath('contrato_final', path, filename: name, contentType: mediaType);
        } catch (e) {
          // fallback to bytes if fromPath fails (some content:// URIs aren't readable)
          final fileBytes = _pickedFile!.bytes ?? File(path).readAsBytesSync();
          multipartFile = http.MultipartFile.fromBytes('contrato_final', fileBytes, filename: name, contentType: mediaType);
        }
      } else {
        final fileBytes = _pickedFile!.bytes;
        if (fileBytes == null) throw Exception('Arquivo selecionado não possui bytes nem path');
        multipartFile = http.MultipartFile.fromBytes('contrato_final', fileBytes, filename: name, contentType: mediaType);
      }
      req.files.add(multipartFile);

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contrato enviado com sucesso')));
        await _load();
      } else {
        // show body for easier debugging
        String body = resp.body;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha: ${resp.statusCode} - ${body.length > 200 ? body.substring(0,200) + '...' : body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _uploadAssinado() async {
    if (_pickedFileSigned == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um arquivo assinado primeiro')));
      return;
    }
    final token = await AuthService.getSavedToken();
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final uri = Uri.parse('$backendHost/propriedades/contratos/${widget.contratoId}/upload_contrato_assinado/');
      final req = http.MultipartRequest('POST', uri);
      req.headers['Authorization'] = 'Bearer $token';

      final name = _pickedFileSigned!.name;
      final path = _pickedFileSigned!.path;
      String ext = '';
      if (name.contains('.')) ext = name.split('.').last.toLowerCase();
      MediaType? mediaType;
      if (ext == 'pdf') mediaType = MediaType('application', 'pdf');
      else if (ext == 'png') mediaType = MediaType('image', 'png');
      else if (ext == 'jpg' || ext == 'jpeg') mediaType = MediaType('image', 'jpeg');
      else if (ext == 'gif') mediaType = MediaType('image', 'gif');
      else mediaType = MediaType('application', 'octet-stream');

      http.MultipartFile multipartFile;
      if (path != null && path.isNotEmpty) {
        try {
          multipartFile = await http.MultipartFile.fromPath('contrato_assinado', path, filename: name, contentType: mediaType);
        } catch (e) {
          final fileBytes = _pickedFileSigned!.bytes ?? File(path).readAsBytesSync();
          multipartFile = http.MultipartFile.fromBytes('contrato_assinado', fileBytes, filename: name, contentType: mediaType);
        }
      } else {
        final fileBytes = _pickedFileSigned!.bytes;
        if (fileBytes == null) throw Exception('Arquivo selecionado não possui bytes nem path');
        multipartFile = http.MultipartFile.fromBytes('contrato_assinado', fileBytes, filename: name, contentType: mediaType);
      }
      req.files.add(multipartFile);

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contrato assinado enviado com sucesso')));
        await _load();
      } else {
        String body = resp.body;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha: ${resp.statusCode} - ${body.length > 200 ? body.substring(0,200) + '...' : body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pagarPrimeiroAluguel() async {
    // Open the payment page (payments are currently disabled/placeholder)
    final contrato = _data;
    if (contrato == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados do contrato não carregados')));
      return;
    }

    String titulo = 'Primeiro Aluguel';
    double valor = 0.0;
    try {
      final imovel = contrato['imovel'];
      if (imovel is Map) {
        titulo = imovel['titulo'] ?? titulo;
        final p = imovel['preco'];
        if (p is num) valor = p.toDouble();
        else if (p is String) valor = double.tryParse(p) ?? 0.0;
      }
    } catch (_) {}

    Navigator.push(context, MaterialPageRoute(builder: (_) => PagamentoPage(contratoId: widget.contratoId, titulo: titulo, valor: valor)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalhes da solicitação', style: GoogleFonts.lato())),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
                ? const Center(child: Text('Não foi possível carregar os dados'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_data!['imovel'] != null ? (_data!['imovel']['titulo'] ?? 'Imóvel') : 'Imóvel', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Solicitante: ${_data!['solicitante'] != null ? (_data!['solicitante']['nome_completo'] ?? _data!['solicitante']['username']) : (_data!['nome_completo'] ?? '')}'),
                      const SizedBox(height: 8),
                      Text('CPF: ${_data!['cpf'] ?? ''}'),
                      Text('Telefone: ${_data!['telefone'] ?? ''}'),
                      const SizedBox(height: 12),
                      if (_data!['comprovante'] != null) ...[
                        Text('Comprovante enviado pelo solicitante:', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          color: const Color(0xFFF7F7FB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: const Icon(Icons.picture_as_pdf, size: 28),
                            title: Text(_fileNameFromUrl(_data!['comprovante'] as String, 'Ver comprovante')),
                            onTap: () {
                              final url = _data!['comprovante'] as String;
                              Navigator.push(context, MaterialPageRoute(builder: (_) => _ComprovantePreview(url: url)));
                            },
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                final url = _data!['comprovante'] as String;
                                if (value == 'open') {
                                  DownloadService.downloadAndOpen(context, url);
                                } else if (value == 'browser') {
                                  UrlLauncherService.openUrlExternal(context, url);
                                } else if (value == 'download') {
                                  UrlLauncherService.openUrlExternal(context, url);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'open', child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Abrir (baixar e abrir)'))),
                                const PopupMenuItem(value: 'browser', child: ListTile(leading: Icon(Icons.open_in_browser), title: Text('Abrir no navegador'))),
                                const PopupMenuItem(value: 'download', child: ListTile(leading: Icon(Icons.download_rounded), title: Text('Baixar'))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_data!['contrato_final'] != null) ...[
                        Text('Contrato final anexado:', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          color: const Color(0xFFF7F7FB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: const Icon(Icons.description, size: 28),
                            title: Text(_fileNameFromUrl(_data!['contrato_final'] as String, 'Ver contrato final')),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ComprovantePreview(url: _data!['contrato_final']))),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                final url = _data!['contrato_final'] as String;
                                if (value == 'open') {
                                  DownloadService.downloadAndOpen(context, url);
                                } else if (value == 'browser') {
                                  UrlLauncherService.openUrlExternal(context, url);
                                } else if (value == 'download') {
                                  UrlLauncherService.openUrlExternal(context, url);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'open', child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Abrir (baixar e abrir)'))),
                                const PopupMenuItem(value: 'browser', child: ListTile(leading: Icon(Icons.open_in_browser), title: Text('Abrir no navegador'))),
                                const PopupMenuItem(value: 'download', child: ListTile(leading: Icon(Icons.download_rounded), title: Text('Baixar'))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // show contrato assinado to both parties when available
                      if (_data!['contrato_assinado'] != null) ...[
                        Text('Contrato assinado (enviado pelo solicitante):', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Card(
                          color: const Color(0xFFF7F7FB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: const Icon(Icons.how_to_reg, size: 28),
                            title: Text(_fileNameFromUrl(_data!['contrato_assinado'] as String, 'Ver contrato assinado')),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ComprovantePreview(url: _data!['contrato_assinado']))),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                final url = _data!['contrato_assinado'] as String;
                                if (value == 'open') {
                                  DownloadService.downloadAndOpen(context, url);
                                } else if (value == 'browser') {
                                  UrlLauncherService.openUrlExternal(context, url);
                                } else if (value == 'download') {
                                  UrlLauncherService.openUrlExternal(context, url);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'open', child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Abrir (baixar e abrir)'))),
                                const PopupMenuItem(value: 'browser', child: ListTile(leading: Icon(Icons.open_in_browser), title: Text('Abrir no navegador'))),
                                const PopupMenuItem(value: 'download', child: ListTile(leading: Icon(Icons.download_rounded), title: Text('Baixar'))),
                              ],
                            ),
                          ),
                        ),
                        //const SizedBox(height: 12),
                        // Primeiro Aluguel button: show immediately below the signed contract only for the solicitante
                        // (double-check the solicitante id to ensure the current user is the one who requested the contract)
                        if (_isSolicitante && (_data!['solicitante'] is Map ? (_data!['solicitante']['id'] == _currentUserId) : true)) ...[
                          ElevatedButton.icon(
                            onPressed: _paying ? null : _pagarPrimeiroAluguel,
                            icon: _paying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.monetization_on),
                            label: _paying ? const Text('Processando...') : const Text('Primeiro Aluguel'),
                          ),
                          //const SizedBox(height: 12),
                        ],
                      ],
                      const Divider(),
                      //const SizedBox(height: 8),
                      // Owner: can attach final contract
                      if (_isOwner) ...[
                        Text('Anexar contrato final (PDF/Imagem):', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (ctx, constraints) => Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(onPressed: _showPickOptions, icon: const Icon(Icons.attach_file), label: const Text('Escolher arquivo')),
                              if (_pickedFile != null)
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: (constraints.maxWidth - 160).clamp(80, constraints.maxWidth)),
                                  child: Text(_pickedFile!.name, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                          ),
                        ),
                        //const SizedBox(height: 12),
                        _loading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(onPressed: _pickedFile == null ? null : _upload, child: const Text('Enviar contrato')),
                      ] else if (_isSolicitante) ...[
                        // Solicitante: can view/download contrato_final and upload contrato_assinado
                        if (_data!['contrato_final'] != null) ...[
                          Text('', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ComprovantePreview(url: _data!['contrato_final']))),
                            child: Text('Ver/baixar contrato final', style: TextStyle(color: Theme.of(context).primaryColor)),
                          ),
                          //const SizedBox(height: 12),
                        ],
                        Text('Enviar contrato assinado (PDF/Imagem):', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (ctx, constraints) => Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(onPressed: _showPickOptionsAssinado, icon: const Icon(Icons.attach_file), label: const Text('Escolher arquivo')),
                              if (_pickedFileSigned != null)
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: (constraints.maxWidth - 160).clamp(80, constraints.maxWidth)),
                                  child: Text(_pickedFileSigned!.name, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _loading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(onPressed: _pickedFileSigned == null ? null : _uploadAssinado, child: const Text('Enviar contrato assinado')),
                      ],
                      const SizedBox(height: 12),
                    ],
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
      // fallthrough
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    final lower = url.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Arquivo (PDF)')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Arquivo')),
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
            label: const Text('Baixar'),
            onPressed: () => UrlLauncherService.openUrlExternal(context, url),
          ),
        ],
      ),
    );
  }
}
