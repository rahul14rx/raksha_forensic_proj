import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'picker.dart';

Future<PickedLogFile?> pickLogFileImpl() async {
  final input = html.FileUploadInputElement()
    ..accept = '.json,.csv,.txt,*/*'
    ..multiple = false
    ..style.display = 'none';

  html.document.body?.append(input);

  final picked = Completer<html.File?>();
  late final StreamSubscription sub;

  sub = input.onChange.listen((_) {
    final files = input.files;
    picked.complete((files == null || files.isEmpty) ? null : files.first);
    sub.cancel();
  });

  input.click();

  final f = await picked.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () => null,
  );

  input.remove();

  if (f == null) return null;

  final r = html.FileReader();
  final done = Completer<Uint8List>();

  r.readAsArrayBuffer(f);

  r.onLoad.listen((_) {
    final res = r.result;
    if (res is ByteBuffer) {
      done.complete(Uint8List.view(res));
    } else if (res is Uint8List) {
      done.complete(res);
    } else {
      done.completeError('Unexpected file read result');
    }
  });

  r.onError.listen((_) {
    done.completeError(r.error ?? 'File read error');
  });

  final bytes = await done.future;
  return PickedLogFile(name: f.name, bytes: bytes);
}
