import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'picker.dart';

Future<Uint8List> _readAll(Stream<List<int>> s) async {
  final a = <int>[];
  await for (final x in s) {
    a.addAll(x);
  }
  return Uint8List.fromList(a);
}

Future<PickedLogFile?> pickLogFileImpl() async {
  final r = await FilePicker.platform.pickFiles(
    withData: true,
    withReadStream: true,
  );

  if (r == null || r.files.isEmpty) return null;

  final f = r.files.first;

  Uint8List? b = f.bytes;
  if (b == null && f.readStream != null) {
    b = await _readAll(f.readStream!);
  }
  if (b == null) return null;

  return PickedLogFile(name: f.name, bytes: b);
}
