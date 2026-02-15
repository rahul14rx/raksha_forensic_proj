import 'dart:typed_data';

import 'picker_stub.dart'
if (dart.library.html) 'picker_web.dart'
if (dart.library.io) 'picker_io.dart';

class PickedLogFile {
  final String name;
  final Uint8List bytes;
  PickedLogFile({required this.name, required this.bytes});
}

Future<PickedLogFile?> pickLogFile() => pickLogFileImpl();
