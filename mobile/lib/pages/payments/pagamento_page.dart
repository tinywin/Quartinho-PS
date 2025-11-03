import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';
import '../../core/constants.dart';

/// PagamentoPage simulada.
/// Esta página fornece um formulário de pagamento falso (apenas UI) para testes.
class PagamentoPage extends StatefulWidget {
  final int contratoId;
  final String titulo;
  final double valor;

  const PagamentoPage({super.key, required this.contratoId, required this.titulo, required this.valor});

  @override
  State<PagamentoPage> createState() => _PagamentoPageState();
}

// Simple CustomPainter that draws a QR matrix produced by `qr` package.
// We construct the QrCode and paint modules as black squares on white.
class _QrMatrixPainter extends CustomPainter {
  final QrCode qr;
  final Color color;

  _QrMatrixPainter(this.qr, {this.color = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final background = Paint()..color = Colors.white..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, background);

    final int moduleCount = qr.moduleCount;
    final double pixelSize = size.width / moduleCount;

    for (int x = 0; x < moduleCount; x++) {
      for (int y = 0; y < moduleCount; y++) {
        if (qr.isDark(y, x)) {
          final rect = Rect.fromLTWH(x * pixelSize, y * pixelSize, pixelSize, pixelSize);
          canvas.drawRect(rect, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PagamentoPageState extends State<PagamentoPage> {
  final _formKey = GlobalKey<FormState>();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvcController = TextEditingController();
  final _nameController = TextEditingController();
  final _pixController = TextEditingController();

  bool _saveCard = true;
  bool _submitting = false;
  int _method = 0; // 0 = card, 1 = pix

  @override
  void dispose() {
    _cardController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    _nameController.dispose();
    _pixController.dispose();
    super.dispose();
  }

  String _maskedCard(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s+'), '');
    final buf = StringBuffer();
    for (var i = 0; i < cleaned.length; i++) {
      if (i != 0 && i % 4 == 0) buf.write(' ');
      buf.write(cleaned[i]);
    }
    return buf.toString();
  }

  Future<void> _submitCard() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _submitting = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pagamento com cartão simulado realizado com sucesso')));
    Navigator.of(context).pop();
  }

  Future<void> _submitPix() async {
    final key = _pixController.text.trim().isEmpty ? 'recebedor@exemplo.com' : _pixController.text.trim();
    setState(() => _submitting = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _submitting = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pix simulado enviado para $key')));
    Navigator.of(context).pop();
  }

  // Build a Pix EMV-like payload (compatible with many QR readers).
  // This is a best-effort implementation inspired by common web utils used
  // in the project; for production use a dedicated library or backend
  // generation according to FEBRABAN / EMV specifications.
  String _tlv(String id, String value) {
    final len = value.length.toString().padLeft(2, '0');
    return id + len + value;
  }

  int _crc16(String input) {
    // CRC-16/CCITT-FALSE (poly 0x1021 init 0xFFFF)
    int crc = 0xFFFF;
    for (int i = 0; i < input.length; i++) {
      crc ^= input.codeUnitAt(i) << 8;
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc & 0xFFFF;
  }

  String _formatAmount(double v) {
    // amount uses dot as decimal separator with up to 2 decimals
    return v.toStringAsFixed(2);
  }

  String _buildPixPayload({
    required String pixKey,
    required String merchantName,
    required String merchantCity,
    required double amount,
    required String txid,
  }) {
    // Field 00: payload format indicator
    String payload = '';
    payload += _tlv('00', '01');

    // Merchant Account Information (26) - Pix
    String mai = '';
    mai += _tlv('00', 'BR.GOV.BCB.PIX');
    mai += _tlv('01', pixKey);
    // txid as kid (25) - optional
    if (txid.isNotEmpty) mai += _tlv('25', txid);
    payload += _tlv('26', mai);

    // Merchant category (52) - default "0000"
    payload += _tlv('52', '0000');
    // Currency (53) - 986 = BRL
    payload += _tlv('53', '986');
    // Amount (54) - optional
    if (amount > 0) payload += _tlv('54', _formatAmount(amount));
    // Country (58)
    payload += _tlv('58', 'BR');
    // Merchant name (59) - max 25 chars
    final mName = merchantName.isEmpty ? 'QUARTINHO' : merchantName;
    payload += _tlv('59', mName.length > 25 ? mName.substring(0, 25) : mName);
    // Merchant city (60) - max 15
    final mCity = merchantCity.isEmpty ? 'CIDADE' : merchantCity;
    payload += _tlv('60', mCity.length > 15 ? mCity.substring(0, 15) : mCity);

    // Add CRC placeholder
    payload += '6304';
    final crc = _crc16(payload);
    final crcHex = crc.toRadixString(16).toUpperCase().padLeft(4, '0');
    payload += crcHex;
    return payload;
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Método de pagamento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Cartões'),
                  selected: _method == 0,
                  onSelected: (v) => setState(() => _method = 0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Pix'),
                  selected: _method == 1,
                  onSelected: (v) => setState(() => _method = 1),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Card form
            if (_method == 0)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.radio_button_checked, size: 18),
                          SizedBox(width: 8),
                          Text('Cartões', style: TextStyle(fontWeight: FontWeight.w600)),
                          Spacer(),
                          Icon(Icons.credit_card, size: 28),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _cardController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(19)],
                              decoration: const InputDecoration(labelText: 'Número do cartão', hintText: '1234 5678 9012 3456'),
                              onChanged: (v) {
                                final formatted = _maskedCard(v);
                                if (formatted != v) {
                                  _cardController.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
                                }
                              },
                              validator: (v) {
                                final cleaned = v?.replaceAll(' ', '') ?? '';
                                if (cleaned.length < 13) return 'Número de cartão inválido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _expiryController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')), LengthLimitingTextInputFormatter(5)],
                                    decoration: const InputDecoration(labelText: 'Prazo', hintText: 'MM/AA'),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Validade inválida';
                                      // Basic MM/AA check (05/24)
                                      if (v.length != 5 || !v.contains('/')) return 'Formato MM/AA';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    controller: _cvcController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                                    decoration: const InputDecoration(labelText: 'CVC/CVV', hintText: 'CVC'),
                                    validator: (v) => (v == null || v.length < 3) ? 'CVC inválido' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Nome no cartão', hintText: 'Nome no cartão'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nome é obrigatório' : null,
                            ),
                            const SizedBox(height: 8),
                            Align(alignment: Alignment.centerLeft, child: Text('Este cartão será armazenado na sua conta', style: Theme.of(context).textTheme.bodySmall)),
                            const SizedBox(height: 10),
                            Row(children: [Checkbox(value: _saveCard, onChanged: (v) => setState(() => _saveCard = v ?? true)), const SizedBox(width: 6), const Text('Salvar cartão')]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // PIX form
            if (_method == 1)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.flash_on, size: 20),
                          SizedBox(width: 8),
                          Text('Pix', style: TextStyle(fontWeight: FontWeight.w600)),
                          Spacer(),
                          Icon(Icons.qr_code, size: 28),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Pague rapidamente usando Pix. Insira sua chave ou use a chave do recebedor abaixo.', style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      TextFormField(controller: _pixController, decoration: const InputDecoration(labelText: 'Chave PIX', hintText: 'e.g. email, telefone ou CPF')),
                      const SizedBox(height: 12),
                      // Generate payload and txid
                      Builder(builder: (ctx) {
                        final pixKey = _pixController.text.trim().isEmpty ? 'recebedor@exemplo.com' : _pixController.text.trim();
                        final txidCandidate = 'c${widget.contratoId}-${DateTime.now().millisecondsSinceEpoch}';
                        final txid = txidCandidate.length <= 25 ? txidCandidate : txidCandidate.substring(0, 25);
                        final merchantName = widget.titulo.isEmpty ? 'QUARTINHO' : widget.titulo;
                        final merchantCity = 'CIDADE';
                        final payload = _buildPixPayload(pixKey: pixKey, merchantName: merchantName, merchantCity: merchantCity, amount: widget.valor, txid: txid);

                        return Column(
                          children: [
                            // QR preview
                            Center(
                              child: Card(
                                              elevation: 0,
                                              color: kPaletteSoft,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SizedBox(
                                    width: 200,
                                    height: 200,
                                    child: Builder(builder: (_) {
                                      try {
                                        final qrCode = QrCode(4, QrErrorCorrectLevel.L);
                                        qrCode.addData(payload);
                                        qrCode.make();
                                        return CustomPaint(
                                          size: const Size(200, 200),
                                          painter: _QrMatrixPainter(qrCode, color: Colors.black),
                                        );
                                      } catch (e) {
                                        return const SizedBox.shrink();
                                      }
                                    }),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Payload and key area
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Payload PIX (copiar):', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(child: SelectableText(payload, style: const TextStyle(fontSize: 12),)),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: payload));
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payload PIX copiado')));
                                      },
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: SelectableText('Chave do recebedor: $pixKey', style: TextStyle(color: Colors.blue[800]))),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: pixKey));
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chave recebida copiada')));
                                      },
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Após efetuar a transferência via PIX, clique em "Já paguei (simular)" para confirmar.', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: kPalettePrimary),
                                      onPressed: _submitting ? null : _submitPix,
                                      child: _submitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Já paguei (simular)'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: kPaletteAccent),
                                      onPressed: () {
                                        // Optional external checkout could be triggered here
                                      },
                                      child: const Text('Outro método'),
                                    ),
                                  ],
                                )
                              ],
                            )
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : () {
                    if (_method == 0) {
                      _submitCard();
                    } else {
                      // Pix has its own action inside the PIX card
                    }
                  },
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: kPalettePrimary),
                  child: _submitting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Pagar R\$ ${widget.valor.toStringAsFixed(2)}'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ],
        ),
      ),
    );
  }
}
