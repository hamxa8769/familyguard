import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves [bytes] to a temp file and opens the system share sheet so the
/// parent can save it to Downloads/Photos or send it elsewhere.
/// Returns true when the share sheet opened.
Future<bool> saveAndShareBytes(
  BuildContext context,
  Uint8List bytes,
  String filename, {
  String? mimeType,
}) async {
  final safe = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType, name: safe)]),
    );
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share file: $e')),
      );
    }
    return false;
  }
}
