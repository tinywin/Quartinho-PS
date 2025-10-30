import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/services/auth_service.dart';

class PreferenceSwitchPage extends StatefulWidget {
  const PreferenceSwitchPage({super.key});

  @override
  State<PreferenceSwitchPage> createState() => _PreferenceSwitchPageState();
}

class _PreferenceSwitchPageState extends State<PreferenceSwitchPage> {
  String? _currentPreference; // 'room' ou 'roommate'
  String? _selectedPreference;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await AuthService.getSavedToken();
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Você precisa estar logado para alterar a preferência.';
      });
      return;
    }
    final me = await AuthService.me(token: token);
    setState(() {
      _currentPreference = me?['preference']?.toString();
      _selectedPreference = _currentPreference;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_selectedPreference == null) return;
    final token = await AuthService.getSavedToken();
    if (token == null) {
      setState(() => _error = 'Sessão expirada. Faça login novamente.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final ok = await AuthService.updatePreference(
      token: token,
      preferenceType: _selectedPreference!,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferência atualizada com sucesso.')),
      );
      Navigator.pop(context, _selectedPreference);
    } else {
      setState(() => _error = 'Não foi possível salvar sua preferência.');
    }
  }

  Widget _option({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedPreference == value;
    return InkWell(
      onTap: () => setState(() => _selectedPreference = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFFFF8533) : const Color(0xFFE5E7EB), width: 2),
          color: selected ? const Color(0xFFFFF3E8) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFFFF8533) : const Color(0xFFF3F4F7),
              ),
              child: Icon(icon, color: selected ? Colors.white : const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF6B7280))),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? const Color(0xFFFF8533) : const Color(0xFFD1D5DB), width: 2),
                color: selected ? const Color(0xFFFF8533) : Colors.transparent,
              ),
              child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Como você quer usar o app?',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEFEF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_error!, style: GoogleFonts.poppins(color: const Color(0xFFB91C1C))),
                    ),
                  const SizedBox(height: 12),
                  _option(
                    value: 'room',
                    icon: Icons.home_outlined,
                    title: 'Procurando um quarto',
                    subtitle: 'Quero encontrar um quarto disponível para alugar',
                  ),
                  const SizedBox(height: 12),
                  _option(
                    value: 'roommate',
                    icon: Icons.people_outline,
                    title: 'Procurando colega de quarto',
                    subtitle: 'Tenho um quarto e quero encontrar alguém para dividir',
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_selectedPreference == null || _saving) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8533),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_saving ? 'Salvando...' : 'Salvar',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}