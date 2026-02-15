import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api.dart';

class FeaturesPage extends StatefulWidget {
  final Api api;
  final String? auditId;
  final String scopeLabel;
  final bool autoRun;
  final VoidCallback? onAutoRunDone;
  final VoidCallback? onNextDetect;

  const FeaturesPage({
    super.key,
    required this.api,
    required this.auditId,
    required this.scopeLabel,
    this.autoRun = false,
    this.onAutoRunDone,
    this.onNextDetect,
  });

  @override
  State<FeaturesPage> createState() => _FeaturesPageState();
}

class _FeaturesPageState extends State<FeaturesPage> {
  bool g = false;
  bool l = false;
  String? e;

  Map<String, dynamic>? out;
  List<Map<String, dynamic>> rows = [];
  int total = 0;

  int page = 0;
  final int pageSize = 200;

  bool _autoBusy = false;

  Future<void> _runAutoOnce() async {
    if (_autoBusy) return;
    _autoBusy = true;
    try {
      await generateAndLoad(reset: true);
    } finally {
      if (mounted) widget.onAutoRunDone?.call();
      _autoBusy = false;
    }
  }

  String _s(dynamic v, [String d = '—']) {
    final x = v?.toString();
    if (x == null || x.isEmpty || x == 'null') return d;
    return x;
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final u = Uri.parse('${widget.api.b}$path');
    final r = await widget.api.c.post(
      u,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode ~/ 100 == 2) {
      try {
        final v = jsonDecode(r.body.isEmpty ? '{}' : r.body);
        if (v is Map<String, dynamic>) return v;
        return {'data': v};
      } catch (_) {
        return {'raw': r.body};
      }
    }
    throw Exception('${r.statusCode} ${r.body}');
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    return widget.api.getJson(path);
  }

  List<Map<String, dynamic>> _filterByAudit(List<Map<String, dynamic>> xs) {
    final id = widget.auditId;
    if (id == null) return xs;
    return xs.where((r) => r['audit_id']?.toString() == id).toList();
  }

  Future<void> generateAndLoad({bool reset = false}) async {
    if (g || l) return;
    if (reset) page = 0;

    setState(() {
      g = true;
      e = null;
      out = null;
      rows = [];
      total = 0;
    });

    try {
      final id = widget.auditId;
      final body = (id == null) ? <String, dynamic>{} : {'audit_id': id};
      final r = await _postJson('/api/generate-features', body);

      if (!mounted) return;
      setState(() => out = r);

      final it = (r['items'] as List?) ?? [];
      if (it.isNotEmpty) {
        final xs = it.map((x) => Map<String, dynamic>.from(x as Map)).toList();
        final ys = _filterByAudit(xs);
        if (!mounted) return;
        setState(() {
          rows = ys;
          final rr = r ?? <String, dynamic>{};
          total = (rr['total'] as int?) ?? ys.length;
        });
      } else {
        await loadRows(reset: false);
      }
    } catch (x) {
      if (!mounted) return;
      setState(() => e = x.toString());
    } finally {
      if (!mounted) return;
      setState(() => g = false);
    }
  }

  Future<void> loadRows({bool reset = false}) async {
    if (l) return;
    if (reset) page = 0;

    setState(() {
      l = true;
      e = null;
    });

    try {
      final id = widget.auditId;
      final qs = <String, String>{
        'limit': '$pageSize',
        'offset': '${page * pageSize}',
      };
      if (id != null) qs['audit_id'] = id;

      final q = qs.entries
          .map((x) => '${Uri.encodeQueryComponent(x.key)}=${Uri.encodeQueryComponent(x.value)}')
          .join('&');

      Map<String, dynamic>? r;
      try {
        r = await _getJson('/api/features/preview?$q');
      } catch (_) {
        try {
          r = await _getJson('/api/ledger/list?$q');
        } catch (_) {
          r = null;
        }
      }

      if (r == null) {
        if (!mounted) return;
        setState(() {
          rows = const [];
          total = 0;
          e = 'Feature table endpoint not available. Generation ran, but preview is not exposed by backend.';
        });
        return;
      }

      final it = (r['items'] as List?) ?? [];
      final xs = it.map((x) => Map<String, dynamic>.from(x as Map)).toList();
      final ys = _filterByAudit(xs);

      if (!mounted) return;
      setState(() {
        final rm = r ?? <String, dynamic>{};
        total = (rm['total'] as int?) ?? ys.length;
        rows = ys;
      });
    } catch (x) {
      if (!mounted) return;
      setState(() => e = x.toString());
    } finally {
      if (!mounted) return;
      setState(() => l = false);
    }
  }

  Widget _scopePill() {
    final id = widget.auditId;
    final t = (id == null) ? 'Scope: ${widget.scopeLabel}' : 'Scope: ${widget.scopeLabel} • $id';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(t, style: const TextStyle(fontFamily: 'monospace')),
    );
  }

  Widget _unknownTimeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        border: Border.all(color: Colors.orange.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text('parse incomplete', style: TextStyle(fontSize: 11)),
    );
  }

  Widget _table() {
    if (l) return const LinearProgressIndicator();
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text('No feature rows to show. Run generation first.'),
      );
    }

    final keys = rows.first.keys.map((x) => x.toString()).toList();
    keys.sort((a, b) {
      if (a == 'audit_id') return -1;
      if (b == 'audit_id') return 1;
      if (a == 'timestamp') return -1;
      if (b == 'timestamp') return 1;
      return a.compareTo(b);
    });

    final shown = keys.take(10).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
        columns: [
          for (final k in shown) DataColumn(label: Text(k)),
        ],
        rows: rows.map((r) {
          return DataRow(
            cells: [
              for (final k in shown)
                DataCell(
                  k == 'timestamp' &&
                      (r[k] == null || r[k].toString() == 'null' || r[k].toString().isEmpty)
                      ? Row(
                    children: [
                      const Text('Unknown time'),
                      const SizedBox(width: 8),
                      _unknownTimeBadge(),
                    ],
                  )
                      : Text(_s(r[k])),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.autoRun && !_autoBusy && !g && !l) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _runAutoOnce();
      });
    }

    final pages = ((total + pageSize - 1) / pageSize).floor().clamp(1, 9999);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Features', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(width: 12),
              _scopePill(),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: (g || l) ? null : () => loadRows(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh table'),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: (g || l) ? null : () => generateAndLoad(reset: true),
                icon: const Icon(Icons.auto_awesome),
                label: Text(g ? 'Generating…' : 'Generate Features'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (e != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(e!, style: const TextStyle(color: Colors.red)),
              ),
            ),
          if (out != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
                color: Colors.black.withOpacity(0.03),
              ),
              child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(out),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: _table()))),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Page ${page + 1} / $pages', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              OutlinedButton(
                onPressed: page <= 0
                    ? null
                    : () {
                  setState(() => page -= 1);
                  loadRows();
                },
                child: const Text('Prev'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: ((page + 1) * pageSize) >= total
                    ? null
                    : () {
                  setState(() => page += 1);
                  loadRows();
                },
                child: const Text('Next'),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: widget.onNextDetect,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next: Detect'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
