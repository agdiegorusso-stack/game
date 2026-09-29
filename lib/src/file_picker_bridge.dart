import 'dart:io';
import 'package:file_picker/file_picker.dart' as native;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
export 'package:file_picker/file_picker.dart' show FileType;
/// Small adapter around the native v13 single-file picker.
/// Streams into app-private cache instead of loading entire videos into RAM.
class FilePicker {
  FilePicker._();
  static final FilePicker platform = FilePicker._();
  Future<PickedFiles?> pickFiles({required native.FileType type, List<String>? allowedExtensions, bool allowMultiple = false, bool withData = false}) async {
    if (allowMultiple || withData) throw UnsupportedError('Only streamed single-file selection is supported.');
    final chosen = await native.FilePicker.pickFile(type: type, allowedExtensions: allowedExtensions);
    if (chosen == null) return null;
    const maxBytes = 200 * 1024 * 1024;
    final reported = await chosen.length();
    if (reported != null && reported > maxBytes) throw const FormatException('File troppo grande: massimo 200 MB.');
    final directory = await getTemporaryDirectory();
    final destination = File(path.join(directory.path, 'picked-${DateTime.now().microsecondsSinceEpoch}-${path.basename(chosen.name)}'));
    final sink = destination.openWrite();
    int size = 0;
    try {
      await for (final chunk in chosen.readAsByteStream()) {
        size += chunk.length;
        if (size > maxBytes) throw const FormatException('File troppo grande: massimo 200 MB.');
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
    return PickedFiles([PickedFile(name: chosen.name, size: size, path: destination.path)]);
  }
}
class PickedFiles {
  final List<PickedFile> files;
  const PickedFiles(this.files);
}
class PickedFile {
  final String name;
  final int size;
  final String? path;
  const PickedFile({required this.name, required this.size, required this.path});
}
