import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants.dart';
import 'url_launcher_service.dart';
import 'package:flutter/services.dart';

class DownloadService {
  /// Download [url] using the saved JWT authorization header (if available)
  /// and save it under the app external directory in a `Quartinho` folder.
  /// Shows SnackBars to indicate progress and returns the saved File on success.
  static Future<File?> downloadFile(BuildContext context, String url, {String? suggestedName}) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Iniciando download...')));

    // normalize URL like other code
    String finalUrl = url;
    if (!finalUrl.startsWith('http')) {
      if (finalUrl.startsWith('/')) finalUrl = '$backendHost$finalUrl';
      else finalUrl = '$backendHost/$finalUrl';
    }

    final token = await AuthService.getSavedToken();
    try {
      final resp = await http.get(Uri.parse(finalUrl), headers: token != null ? {'Authorization': 'Bearer $token'} : {});
      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha no download: ${resp.statusCode}')));
        return null;
      }

      final bytes = resp.bodyBytes;

      // determine filename
      String filename = suggestedName ?? _fileNameFromUrl(finalUrl) ?? 'arquivo_down';
      // ensure unique name
      final dir = await _storageDir();
      if (!await dir.exists()) await dir.create(recursive: true);
      var outFile = File('${dir.path}/$filename');
      int i = 1;
      while (await outFile.exists()) {
        final dot = filename.lastIndexOf('.');
        if (dot > 0) {
          final name = filename.substring(0, dot);
          final ext = filename.substring(dot);
          outFile = File('${dir.path}/$name($i)$ext');
        } else {
          outFile = File('${dir.path}/$filename($i)');
        }
        i++;
      }

      await outFile.writeAsBytes(bytes);

      // Try to move file to public Downloads via platform channel (Android)
      try {
        final channel = const MethodChannel('quartinho/download');
        final mime = _mimeFromFilename(filename);
        final res = await channel.invokeMethod<String>('saveFileToDownloads', {'path': outFile.path, 'displayName': filename, 'mimeType': mime});
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Arquivo salvo em Downloads: $filename'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: 'Abrir', onPressed: () => UrlLauncherService.openUrlExternal(context, res)),
          ));
          return outFile;
        }
      } catch (e) {
        // ignore and fallback to app-specific path
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Arquivo salvo em: ${outFile.path}'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'Abrir', onPressed: () => UrlLauncherService.openUrlExternal(context, Uri.file(outFile.path).toString())),
      ));

      return outFile;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao baixar: $e')));
      return null;
    }
  }

  /// Download the file and open it immediately when saved.
  static Future<void> downloadAndOpen(BuildContext context, String url, {String? suggestedName}) async {
    final file = await downloadFile(context, url, suggestedName: suggestedName);
    if (file != null) {
      try {
        await UrlLauncherService.openUrlExternal(context, Uri.file(file.path).toString());
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao abrir arquivo: $e')));
      }
    }
  }

  static Future<Directory> _storageDir() async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        // use a 'Quartinho' subfolder
        return Directory('${ext.path}/Quartinho');
      }
    } catch (_) {}
    // fallback to temporary directory
    final tmp = await getTemporaryDirectory();
    return Directory('${tmp.path}/Quartinho');
  }

  static String? _fileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last;
        if (last.isNotEmpty) return last;
      }
    } catch (_) {}
    final parts = url.split('/');
    for (var i = parts.length - 1; i >= 0; i--) {
      if (parts[i].trim().isNotEmpty) return parts[i];
    }
    return null;
  }

  static String _mimeFromFilename(String filename) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return '*/*';
    }
  }
}
