import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps a picked photo somewhere the app owns.
///
/// The picker hands back a copy in the cache directory, which the system may
/// clear whenever it likes; a pilgrimage photo that vanishes a month later
/// is not something the devotee can take again. On the web there is no
/// file system, so the picker's own URL is kept as it is.
class PhotoStore {
  const PhotoStore._();

  static Future<String> keep(XFile picked, {String folder = 'memories'}) async {
    if (kIsWeb) return picked.path;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/$folder');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final dot = picked.path.lastIndexOf('.');
      final ext = dot >= 0 && picked.path.length - dot <= 5 ? picked.path.substring(dot) : '.jpg';
      final target = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}$ext';
      await File(picked.path).copy(target);
      return target;
    } catch (_) {
      // Better the cache copy than no photo at all.
      return picked.path;
    }
  }

  /// Deletes a copy made by [keep]. Anything else is left alone.
  static Future<void> discard(String? path) async {
    if (kIsWeb || path == null) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      if (path.startsWith(docs.path)) {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      }
    } catch (_) {}
  }
}
