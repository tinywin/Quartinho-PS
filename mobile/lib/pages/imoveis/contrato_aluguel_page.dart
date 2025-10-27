import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../core/services/auth_service.dart';
import '../../core/constants.dart';

class ContratoAluguelPage extends StatefulWidget {
  final Map imovel;
  const ContratoAluguelPage({super.key, required this.imovel});

  @override
  State<ContratoAluguelPage> createState() => _ContratoAluguelPageState();
}

class _ContratoAluguelPageState extends State<ContratoAluguelPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeCtrl = TextEditingController();
  final TextEditingController _telefoneCtrl = TextEditingController();
  final TextEditingController _cpfCtrl = TextEditingController();
  XFile? _comprovanteFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _telefoneCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    _submit();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_comprovanteFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, envie um comprovante de renda.')));
      return;
    }

    final token = await AuthService.getSavedToken();
    if (token == null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SizedBox()));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('É necessário estar logado para enviar.')));
      return;
    }

    final url = Uri.parse('$backendHost/propriedades/contratos/');
    final req = http.MultipartRequest('POST', url);
    req.headers['Authorization'] = 'Bearer $token';

    req.fields['imovel'] = (widget.imovel['id'] ?? widget.imovel['pk'] ?? widget.imovel['id']).toString();
    req.fields['nome_completo'] = _nomeCtrl.text.trim();
    req.fields['cpf'] = _cpfCtrl.text.trim();
    req.fields['telefone'] = _telefoneCtrl.text.trim();

    // anexar comprovante
    try {
      final file = await http.MultipartFile.fromPath('comprovante', _comprovanteFile!.path);
      req.files.add(file);
    } catch (e) {
      // ignore: avoid_print
      print('Erro anexando arquivo: $e');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      Navigator.pop(context); // fecha o loading
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviado para análise.')));
        Navigator.pop(context);
      } else if (resp.statusCode == 401) {
        await AuthService.logout();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sessão expirada. Faça login novamente.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar: ${resp.statusCode}')));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro na requisição: $e')));
    }
  }

  Future<void> _pickComprovante() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (file != null) {
        setState(() {
          _comprovanteFile = file;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Erro ao escolher comprovante: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.imovel['titulo']?.toString() ?? 'Imóvel';
    final preco = widget.imovel['preco_total'] ?? widget.imovel['preco'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Contrato de aluguel', style: GoogleFonts.lato()),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Preço: R\$ $preco / mês', style: GoogleFonts.lato(fontSize: 16)),
            const SizedBox(height: 20),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome completo'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome completo' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cpfCtrl,
                    decoration: const InputDecoration(labelText: 'CPF (apenas números)'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Informe o CPF';
                      final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                      if (digits.length != 11) return 'CPF deve ter 11 dígitos';
                      return null;
                    },
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telefoneCtrl,
                    decoration: const InputDecoration(labelText: 'Telefone para contato'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um telefone' : null,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),

                  // Comprovante
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickComprovante,
                        icon: const Icon(Icons.attach_file),
                        label: const Text('Escolher comprovante'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _comprovanteFile == null ? 'Nenhum arquivo selecionado' : _comprovanteFile!.name,
                          style: GoogleFonts.lato(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (_comprovanteFile != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_comprovanteFile!.path), height: 140, fit: BoxFit.cover),
                    ),
                  ],

                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6E56CF), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                    onPressed: _confirmar,
                    child: Text('Enviar para análise', style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
