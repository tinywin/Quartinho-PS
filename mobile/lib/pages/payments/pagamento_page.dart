import 'package:flutter/material.dart';

/// PagamentoPage placeholder.
/// Payment integrations (Stripe / Mercado Pago) were removed from this project.
/// This page remains as a safe placeholder so navigation from other pages
/// doesn't crash. It simply informs the user that payments are disabled.
class PagamentoPage extends StatelessWidget {
  final int contratoId;
  final String titulo;
  final double valor;

  const PagamentoPage({super.key, required this.contratoId, required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('Valor: R\$ ${valor.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              const Text('Pagamentos estão desativados neste aplicativo.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar')),
            ],
          ),
        ),
      ),
    );
  }
}
