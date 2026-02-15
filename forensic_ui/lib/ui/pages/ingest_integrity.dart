import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../models/audit.dart';
import '../widgets/typing_log.dart';

class IngestIntegrityPage extends StatefulWidget {
  final Api api;
  final void Function(String auditId)? onIngested;
  final void Function(String auditId)? onDoneToChain;

  const IngestIntegrityPage({
    super.key,
    required this.api,
    this.onIngested,
    this.onDoneToChain,
  });

  @override
  State<IngestIntegrityPage> createState() => _IngestIntegrityPageState();
}

class _IngestIntegrityPageState extends State<IngestIntegrityPage> {
  final u = TextEditingController();
  final p = TextEditingController();
  final df = DateFormat('yyyy-MM-dd HH:mm:ss');

  bool up = false;
  bool ok = false;
  String st = 'unknown';
  Timer? t;

  Audit? a;
  Map<String, dynamic>? v;
  Map<String, dynamic>? c;

  final log = <LogItem>[];

  DropzoneViewController? dz;
  bool hov = false;
  bool showPaste = false;

  StreamSubscription<html.Event>? _pasteSub;

  void addLog(String s) {
    setState(() => log.add(LogItem(s)));
  }

  void _maybeGoChain() {
    final id = a?.id;
    if (id == null) return;
    if (v == null || c == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onDoneToChain?.call(id);
    });
  }

  ShapeBorder cardShape() {
    final cs = Theme.of(context).colorScheme;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: cs.outlineVariant.withOpacity(0.7)),
    );
  }

  TextStyle mono(double s, {FontWeight? w}) =>
      TextStyle(fontFamily: 'monospace', fontSize: s, fontWeight: w);

  bool _allowedName(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.csv') ||
        n.endsWith('.txt') ||
        n.endsWith('.json') ||
        n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg');
  }

  @override
  void initState() {
    super.initState();
    ping();
    t = Timer.periodic(const Duration(seconds: 5), (_) => ping());

    if (kIsWeb) {
      _pasteSub = html.document.onPaste.listen((e) {
        final ev = e as html.ClipboardEvent;
        _onPaste(ev);
      });
    }
  }

  @override
  void dispose() {
    t?.cancel();
    _pasteSub?.cancel();
    u.dispose();
    p.dispose();
    super.dispose();
  }

  Future<void> ping() async {
    try {
      final r = await widget.api.health();
      if (!mounted) return;
      setState(() {
        ok = (r['status']?.toString() == 'running');
        st = r['status']?.toString() ?? 'unknown';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        ok = false;
        st = 'down';
      });
    }
  }

  Future<void> pick() async {
    final r = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt', 'json', 'png', 'jpg', 'jpeg'],
    );
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final b = f.bytes;
    if (b == null) return;
    await uploadBytes(b, f.name);
  }

  Future<void> pasteTextFromClipboard() async {
    final d = await Clipboard.getData('text/plain');
    final s = d?.text ?? '';
    setState(() => showPaste = true);
    if (s.trim().isEmpty) {
      addLog('Clipboard text: empty');
      return;
    }
    p.text = s;
    addLog('Clipboard text pasted (${s.length} chars)');
  }

  Future<void> uploadTextAsLog() async {
    final s = p.text;
    if (s.trim().isEmpty) {
      addLog('Text upload skipped: empty input');
      return;
    }
    final name = 'pasted_log_${DateTime.now().millisecondsSinceEpoch}.txt';
    final b = Uint8List.fromList(utf8.encode(s));
    await uploadBytes(b, name);
  }

  Future<void> _onPaste(html.ClipboardEvent e) async {
    if (!mounted) return;
    if (up) return;

    final cd = e.clipboardData;
    if (cd == null) return;

    final items = cd.items;
    if (items == null) return;

    final len = items.length ?? 0;

    for (var i = 0; i < len; i++) {
      final it = items[i];
      if (it == null) continue;

      final t = (it.type ?? '').toLowerCase();
      final k = (it.kind ?? '').toLowerCase();

      if (k == 'file' && (t == 'image/png' || t == 'image/jpeg')) {
        final f = it.getAsFile();
        if (f == null) continue;

        addLog('Pasted image: ${f.name.isEmpty ? '(clipboard)' : f.name}');
        addLog('Uploading to ledger (SHA-256 + previous hash)…');

        final fr = html.FileReader();
        fr.readAsArrayBuffer(f);
        await fr.onLoad.first;

        final r = fr.result;
        Uint8List b;
        if (r is ByteBuffer) {
          b = Uint8List.view(r);
        } else if (r is Uint8List) {
          b = r;
        } else {
          addLog('Paste failed: unsupported clipboard buffer');
          return;
        }

        final name = f.name.isEmpty
            ? 'pasted_${DateTime.now().millisecondsSinceEpoch}.${t == "image/png" ? "png" : "jpg"}'
            : f.name;

        await uploadBytes(b, name);
        break;
      }
    }
  }

  Future<void> uploadBytes(Uint8List b, String name) async {
    if (up) return;
    setState(() {
      up = true;
      v = null;
      c = null;
    });

    addLog('Selected: $name');

    if (!_allowedName(name)) {
      addLog('Rejected: unsupported file type. Allowed: csv/txt/json/png/jpg/jpeg');
      setState(() => up = false);
      return;
    }

    addLog('Uploading to ledger (SHA-256 + previous hash)…');

    try {
      final r = await widget.api.upload(bytes: b, name: name, u: u.text);
      final au = Audit.fromJson(r);

      addLog('Upload complete. Audit ID: ${au.id}');
      addLog('Parsing + normalizing… writing Parquet to cold storage…');

      if (!mounted) return;
      setState(() => a = au);

      widget.onIngested?.call(au.id);

      addLog('Auto: verifying file integrity…');
      await verifyFile();

      addLog('Auto: scheduling chain verify in 4s…');
      Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        verifyChain();
      });
    } catch (e) {
      addLog('Upload failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => up = false);
    }
  }

  Future<void> verifyFile() async {
    final au = a;
    if (au == null) return;

    addLog('Verifying file integrity for ${au.id}…');
    try {
      final r = await widget.api.verify(au.id);
      if (!mounted) return;
      setState(() => v = r);
      addLog('Verify result: ${r['status']}');
      _maybeGoChain();
    } catch (e) {
      addLog('Verify failed: $e');
    }
  }

  Future<void> verifyChain() async {
    addLog('Verifying hash chain…');
    try {
      final r = await widget.api.verifyChain();
      if (!mounted) return;
      setState(() => c = r);
      addLog('Chain result: ${r['status']}');
      _maybeGoChain();
    } catch (e) {
      addLog('Chain verify failed: $e');
    }
  }

  Widget badge() {
    final cs = Theme.of(context).colorScheme;
    final col = ok ? cs.tertiary : cs.error;
    final txt = ok ? 'Backend: $st' : 'Backend: down';

    return Material(
      color: col.withOpacity(0.10),
      shape: StadiumBorder(side: BorderSide(color: col.withOpacity(0.45))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: col, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              txt,
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: ping,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Refresh health',
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget auditCard(Audit x) {
    final cs = Theme.of(context).colorScheme;

    Widget row(String k, String v, {bool monoVal = false}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                k,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.70),
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                v,
                style: monoVal
                    ? mono(12.5)
                    : TextStyle(color: cs.onSurface.withOpacity(0.92)),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: cs.primary),
                const SizedBox(width: 10),
                const Text('Audit Receipt',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    x.status,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            row('audit_id', x.id, monoVal: true),
            row('filename', x.filename),
            row('file_size', '${x.fileSize} bytes'),
            row('upload_time', df.format(x.uploadTime.toLocal())),
            row('sha256_hash', x.sha256Hash, monoVal: true),
            row('previous_hash', x.previousHash ?? 'null', monoVal: true),
          ],
        ),
      ),
    );
  }

  Widget statusBox(String title, Map<String, dynamic> m) {
    final cs = Theme.of(context).colorScheme;
    final s = (m['status'] ?? '').toString();

    final col = (s.contains('valid') ||
        s.contains('complete') ||
        s.contains('generated'))
        ? cs.tertiary
        : (s.contains('broken') ||
        s.contains('tampered') ||
        s.contains('error'))
        ? cs.error
        : cs.secondary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: col.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: col.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: col.withOpacity(0.35)),
                  ),
                  child: Text(
                    s.isEmpty ? 'unknown' : s,
                    style: TextStyle(fontWeight: FontWeight.w800, color: col),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.8)),
              ),
              child: SelectableText(m.toString(), style: mono(12.0)),
            ),
          ],
        ),
      ),
    );
  }

  Widget attachPanel() {
    final cs = Theme.of(context).colorScheme;

    final borderCol =
    hov ? cs.primary.withOpacity(0.55) : cs.outlineVariant.withOpacity(0.75);

    final bg = hov
        ? cs.surfaceVariant.withOpacity(0.55)
        : cs.surfaceVariant.withOpacity(0.35);

    final fg = cs.onSurface;
    final sub = cs.onSurface.withOpacity(0.65);

    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.70)),
        ),
        child: Stack(
          children: [
            if (kIsWeb)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: DropzoneView(
                    onCreated: (c) => dz = c,
                    onHover: () => setState(() => hov = true),
                    onLeave: () => setState(() => hov = false),
                    onDropFile: (f) async {
                      setState(() => hov = false);
                      try {
                        if (dz == null) return;
                        final name = await dz!.getFilename(f);
                        if (!_allowedName(name)) {
                          addLog('Rejected drop: $name (unsupported type)');
                          return;
                        }
                        addLog('Dropped: $name');
                        final data = await dz!.getFileData(f);
                        final b = Uint8List.fromList(data);
                        await uploadBytes(b, name);
                      } catch (e) {
                        addLog('Drop failed: $e');
                      }
                    },
                  ),
                ),
              ),
            DashedBorder(
              radius: 18,
              color: borderCol,
              strokeWidth: 1.2,
              dash: 8,
              gap: 6,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'or drop your files',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'csv, txt, json, png, jpg, jpeg',
                      style: TextStyle(color: sub, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: up ? null : pick,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload files'),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: up ? null : pasteTextFromClipboard,
                          icon: const Icon(Icons.content_paste),
                          label: const Text('Copied text'),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.surfaceVariant.withOpacity(0.65),
                            foregroundColor: cs.onSurface,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Paste image with Ctrl + V')),
                            );
                          },
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Paste image'),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.surfaceVariant.withOpacity(0.65),
                            foregroundColor: cs.onSurface,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: cs.outlineVariant.withOpacity(0.75)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.edit_note,
                              color: cs.onSurface.withOpacity(0.65)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: p,
                              minLines: 1,
                              maxLines: 4,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Paste or type text here…',
                                hintStyle: TextStyle(
                                    color: cs.onSurface.withOpacity(0.55)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            tooltip: 'Upload text as .txt',
                            onPressed: (up || p.text.trim().isEmpty)
                                ? null
                                : uploadTextAsLog,
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget uploadCard() {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.cloud_upload_outlined, color: cs.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ingest & Store',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text(
                        'Upload evidence or paste raw logs.',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (up) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(minHeight: 6),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: u,
              decoration: InputDecoration(
                labelText: 'Uploader (optional)',
                hintText: 'e.g., Rahul / Officer A / Lab 2',
                prefixIcon: const Icon(Icons.badge_outlined),
                filled: true,
                fillColor: cs.surfaceVariant.withOpacity(0.35),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                  BorderSide(color: cs.outlineVariant.withOpacity(0.8)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            attachPanel(),
            const SizedBox(height: 14),
            if (a != null) auditCard(a!),
          ],
        ),
      ),
    );
  }

  Widget integrityCard() {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.secondary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.verified_outlined, color: cs.secondary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Integrity',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text(
                        'Verify file hash and validate the chain-of-custody ledger.',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (a == null) ? null : verifyFile,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Verify this file'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: verifyChain,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link),
                        SizedBox(width: 8),
                        Text('Verify full chain'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (v != null) ...[
              statusBox('File verify', v!),
              const SizedBox(height: 10),
            ],
            if (c != null) ...[
              statusBox('Chain verify', c!),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            const Text('Activity', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.8)),
                  color: cs.surfaceVariant.withOpacity(0.18),
                ),
                child: DefaultTextStyle(
                  style: TextStyle(color: cs.onSurface.withOpacity(0.92)),
                  child: TypingLog(items: log),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ONLY CHANGE IS HERE: removed the top header Row + badge from the page
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cs) {
        final wide = cs.maxWidth >= 1100;

        final left = uploadCard();
        final right = SizedBox(
          height: wide ? double.infinity : 520,
          child: integrityCard(),
        );

        final t0 = Theme.of(context);
        final c0 = t0.colorScheme;

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c0.primary.withOpacity(0.06),
                c0.surface,
                c0.secondary.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: wide
                      ? Row(
                    children: [
                      Expanded(flex: 6, child: left),
                      const SizedBox(width: 14),
                      Expanded(flex: 4, child: right),
                    ],
                  )
                      : ListView(
                    children: [
                      left,
                      const SizedBox(height: 14),
                      right,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DashedBorder extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  const DashedBorder({
    super.key,
    required this.child,
    required this.radius,
    required this.color,
    this.strokeWidth = 1.2,
    this.dash = 8,
    this.gap = 6,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        radius: radius,
        color: color,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final double radius;
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  _DashedBorderPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final path = Path()..addRRect(r);

    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final len = math.min(dash, metric.length - dist);
        final seg = metric.extractPath(dist, dist + len);
        canvas.drawPath(seg, paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) {
    return old.radius != radius ||
        old.color != color ||
        old.strokeWidth != strokeWidth ||
        old.dash != dash ||
        old.gap != gap;
  }
}