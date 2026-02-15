import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/api.dart';

class ChainCustodyPage extends StatefulWidget {
  final Api api;
  final String? initialAuditId;
  final VoidCallback? onNextFeatures;

  const ChainCustodyPage({
    super.key,
    required this.api,
    this.initialAuditId,
    this.onNextFeatures,
  });

  @override
  State<ChainCustodyPage> createState() => _ChainCustodyPageState();
}

class _ChainCustodyPageState extends State<ChainCustodyPage> {
  bool l = true;
  String? e;

  List<Map<String, dynamic>> items = [];
  Map<String, dynamic>? sel;

  Map<String, dynamic>? verifyOut;
  Map<String, dynamic>? chainOut;

  final q = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  String _ts(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    return iso.replaceFirst('T', ' ').split('.').first;
  }

  String _h(String? s) {
    if (s == null || s.isEmpty) return '—';
    if (s.length <= 12) return s;
    return '${s.substring(0, 8)}…${s.substring(s.length - 4)}';
  }

  String _kb(int? b) {
    if (b == null) return '—';
    final k = b / 1024.0;
    if (k < 1024) return '${k.toStringAsFixed(1)} KB';
    final m = k / 1024.0;
    return '${m.toStringAsFixed(2)} MB';
  }

  Future<void> load() async {
    setState(() {
      l = true;
      e = null;
      verifyOut = null;
      chainOut = null;
    });

    try {
      final r = await widget.api.ledgerList(q: q.text.trim());
      final raw = (r['items'] as List?) ?? [];
      final x = raw.map((z) => Map<String, dynamic>.from(z as Map)).toList();

      Map<String, dynamic>? picked = sel;

      final want = widget.initialAuditId;
      if (want != null && want.isNotEmpty) {
        final hit = x.where((m) => (m['id']?.toString() ?? '') == want);
        if (hit.isNotEmpty) picked = hit.first;
      }

      setState(() {
        items = x;
        sel = picked;
        l = false;
      });
    } catch (x) {
      setState(() {
        e = x.toString();
        l = false;
      });
    }
  }

  Future<void> verifySelected() async {
    final id = sel?['id']?.toString();
    if (id == null || id.isEmpty) return;

    setState(() => verifyOut = null);
    try {
      final r = await widget.api.verify(id);
      setState(() => verifyOut = r);
    } catch (x) {
      setState(() => verifyOut = {'status': 'error', 'message': x.toString()});
    }
  }

  Future<void> verifyFullChain() async {
    setState(() => chainOut = null);
    try {
      final r = await widget.api.verifyChain();
      setState(() => chainOut = r);
    } catch (x) {
      setState(() => chainOut = {'status': 'error', 'message': x.toString()});
    }
  }

  ShapeBorder _cardShape(ColorScheme cs) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: cs.outlineVariant.withOpacity(0.75)),
    );
  }

  TextStyle _mono(double s, {FontWeight? w}) =>
      TextStyle(fontFamily: 'monospace', fontSize: s, fontWeight: w);

  Widget _pill(String t, {Color? bg, Color? fg, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (fg ?? Colors.black).withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg?.withOpacity(0.9)),
            const SizedBox(width: 6),
          ],
          Text(
            t,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _jsonBox(Map<String, dynamic>? m) {
    final cs = Theme.of(context).colorScheme;
    if (m == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.28),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
        ),
        child: Text('—', style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
      );
    }

    final s = const JsonEncoder.withIndent('  ').convert(m);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
      ),
      child: SelectableText(s, style: _mono(12)),
    );
  }

  Widget left() {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: _cardShape(cs),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2_outlined, color: cs.primary),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Evidence Ledger',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                _pill(
                  '${items.length} items',
                  bg: cs.surfaceVariant.withOpacity(0.45),
                  fg: cs.onSurface.withOpacity(0.75),
                  icon: Icons.list_alt,
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: q,
                    decoration: InputDecoration(
                      hintText: 'Search filename / uploader',
                      isDense: true,
                      filled: true,
                      fillColor: cs.surfaceVariant.withOpacity(0.30),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onSubmitted: (_) => load(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: l ? null : load,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),

            const SizedBox(height: 10),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: (!l && e == null)
                  ? const SizedBox.shrink()
                  : Column(
                key: ValueKey('$l|$e'),
                children: [
                  if (l)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(minHeight: 6),
                    ),
                  if (e != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.error.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.error.withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: cs.error),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Error: $e',
                                style: TextStyle(
                                  color: cs.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: items.isEmpty
                  ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inbox_outlined, color: cs.onSurface.withOpacity(0.55)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No evidence yet. Upload logs first.',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.75)),
                      ),
                    ),
                  ],
                ),
              )
                  : LayoutBuilder(
                builder: (context, c) {
                  final rows = items.map((x) {
                    final id = x['id']?.toString() ?? '';
                    final fn = x['filename']?.toString() ?? '—';
                    final ph = x['previous_hash']?.toString();
                    final sh = x['sha256_hash']?.toString();
                    final active = sel?['id']?.toString() == id;

                    return DataRow(
                      selected: active,
                      onSelectChanged: (_) {
                        setState(() {
                          sel = x;
                          verifyOut = null;
                        });
                      },
                      color: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return cs.primary.withOpacity(0.10);
                        }
                        return null;
                      }),
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 240,
                            child: Text(fn, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 160,
                            child: Text(
                              id.isEmpty ? '—' : id.substring(0, min(12, id.length)),
                              style: _mono(12, w: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 240,
                            child: Text(_h(ph), style: _mono(12)),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 240,
                            child: Text(_h(sh), style: _mono(12)),
                          ),
                        ),
                      ],
                    );
                  }).toList();

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: c.maxWidth),
                            child: DataTable(
                              showCheckboxColumn: false,
                              headingRowHeight: 46,
                              dataRowMinHeight: 46,
                              dataRowMaxHeight: 58,
                              dividerThickness: 0.8,
                              headingTextStyle: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: cs.onSurface.withOpacity(0.85),
                              ),
                              dataTextStyle: TextStyle(color: cs.onSurface.withOpacity(0.85)),
                              headingRowColor: MaterialStatePropertyAll(
                                cs.surfaceVariant.withOpacity(0.35),
                              ),
                              columns: const [
                                DataColumn(label: Text('filename')),
                                DataColumn(label: Text('id')),
                                DataColumn(label: Text('previous_hash')),
                                DataColumn(label: Text('sha256_hash')),
                              ],
                              rows: rows,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget right() {
    final cs = Theme.of(context).colorScheme;
    final x = sel;

    String statusPillText(Map<String, dynamic>? out) {
      final s = out?['status']?.toString() ?? '';
      if (s.isEmpty) return 'Not run';
      return s;
    }

    Color statusColor(String s) {
      final t = s.toLowerCase();
      if (t.contains('valid') || t == 'ok') return Colors.green;
      if (t.contains('tamper') || t.contains('broken') || t.contains('error')) return cs.error;
      if (t.contains('warn')) return Colors.orange;
      return cs.primary;
    }

    return Card(
      elevation: 0,
      shape: _cardShape(cs),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: x == null
            ? Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
          ),
          child: Row(
            children: [
              Icon(Icons.touch_app_outlined, color: cs.onSurface.withOpacity(0.55)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select an evidence item from the ledger.',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.75)),
                ),
              ),
            ],
          ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Text('Custody', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: verifySelected,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Verify this file'),
                ),
                OutlinedButton.icon(
                  onPressed: verifyFullChain,
                  icon: const Icon(Icons.link),
                  label: const Text('Verify full chain'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv('Audit ID', x['id']?.toString() ?? '—'),
                  _kv('Filename', x['filename']?.toString() ?? '—'),
                  _kv('Uploader', x['uploader']?.toString() ?? '—'),
                  _kv('Uploaded', _ts(x['upload_time']?.toString())),
                  _kv(
                    'Size',
                    _kb(
                      x['file_size'] is int ? x['file_size'] as int : int.tryParse('${x['file_size']}'),
                    ),
                  ),
                  _kv('Status', x['status']?.toString() ?? '—'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.fingerprint, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text('Hash Link', style: TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('prev:  ${_h(x['previous_hash']?.toString())}', style: _mono(12)),
                  Text('curr:  ${_h(x['sha256_hash']?.toString())}', style: _mono(12)),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Icon(Icons.rule_folder_outlined, color: cs.primary),
                const SizedBox(width: 8),
                const Text('Verify Output', style: TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 8),
            _jsonBox(verifyOut),

            const SizedBox(height: 14),

            Row(
              children: [
                Icon(Icons.all_inclusive, color: cs.primary),
                const SizedBox(width: 8),
                const Text('Chain Output', style: TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 8),
            _jsonBox(chainOut),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onNextFeatures,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next: Generate Features'),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'This ledger is append-only. Each row links to the previous hash, so any edit breaks the chain.',
              style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface.withOpacity(0.75))),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final narrow = w < 1100;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.06),
            cs.surface,
            cs.secondary.withOpacity(0.05),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: narrow
                  ? Column(
                children: [
                  Expanded(child: left()),
                  const SizedBox(height: 12),
                  Expanded(child: right()),
                ],
              )
                  : Row(
                children: [
                  Expanded(flex: 5, child: left()),
                  const SizedBox(width: 12),
                  Expanded(flex: 7, child: right()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}