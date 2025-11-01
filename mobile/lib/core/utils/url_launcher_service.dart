import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class UrlLauncherService {
  /// Try to open [urlString] in the external browser (system handler).
  /// Shows a SnackBar with an error message if it fails.
  static Future<void> openUrlExternal(BuildContext context, String urlString) async {
    if (urlString.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL inválida')));
      return;
    }

    Uri? uri;
    try {
      uri = Uri.parse(urlString);
      if (!uri.hasScheme) {
        // assume http if missing
        uri = Uri.parse('https://$urlString');
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL inválida')));
      return;
    }

    try {
      final can = await canLaunchUrl(uri);
      if (!can) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link')));
        return;
      }

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link')));
      }
    } on MissingPluginException catch (mpe) {
      // Plugin not registered (common when app wasn't reinstalled after adding a plugin)
      final msg = mpe.message ?? 'MissingPluginException';
      print('UrlLauncher MissingPluginException: $msg');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Plugin não registrado: $msg\nTente reinstalar o app (flutter clean && flutter pub get && flutter run).'),
        duration: const Duration(seconds: 6),
      ));
    } on PlatformException catch (pe) {
      // Common case: plugin channel not registered (channel-error)
      final msg = pe.message ?? pe.code;
      print('UrlLauncher PlatformException: ${pe.code} - $msg');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro nativo ao abrir link: $msg\nTente reinstalar o app (flutter clean && flutter pub get && flutter run).'),
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir link: $e')));
    }
  }
}
