import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/api.dart';

class DetectionPage extends StatefulWidget {
  final Api api;
  final String? auditId;
  final bool autoRun;
  final String? scopeLabel;
  final VoidCallback? onAutoRunDone;

  const DetectionPage({
    super.key,
    required this.api,
    this.auditId,
    this.autoRun = false,
    this.scopeLabel,
    this.onAutoRunDone,
  });

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  bool l0 = false;
  bool l1 = false;
  bool l2 = false;
  String? e;

  Map<String, dynamic>? runOut;
  Map<String, dynamic>? sum;

  List<Map<String, dynamic>> rows = [];
  int total = 0;

  bool onlyA = true;
  double minR = 25;
  String sort = 'risk_desc';
  int page = 0;
  final int pageSize = 200;

  final q = TextEditingController();
  Map<String, dynamic>? sel;

  String scope = 'latest'; // all | latest | pick
  String? pickId;
  String? latestId;
  List<Map<String, dynamic>> ingests = [];

  final ScrollController _vCtrl = ScrollController();
  final ScrollController _hCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _vCtrl.dispose();
    _hCtrl.dispose();
    q.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadIngests();

    if (widget.auditId != null && widget.auditId!.trim().isNotEmpty) {
      scope = 'pick';
      pickId = widget.auditId!.trim();
    }

    await refreshAll();

    if (widget.autoRun) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        runDetection();
      });
    }
  }

  String? _activeAuditId() {
    if (scope == 'all') return null;
    if (scope == 'latest') return latestId;
    if (scope == 'pick') return pickId;
    return null;
  }

  Future<void> _loadIngests() async {
    setState(() {
      l0 = true;
      e = null;
    });

    try {
      final r = await widget.api.ledgerList(limit: 200, offset: 0, q: '');

      final it = (r['items'] as List?) ?? [];
      ingests = it.map((x) => Map<String, dynamic>.from(x as Map)).toList();

      String? bestId;
      String? bestTime;

      for (final x in ingests) {
        final t = x['upload_time']?.toString();
        if (t == null || t.isEmpty || t == 'null') continue;
        if (bestTime == null || t.compareTo(bestTime) > 0) {
          bestTime = t;
          bestId = x['audit_id']?.toString();
        }
      }

      latestId = bestId;
      setState(() => l0 = false);
    } catch (x) {
      setState(() {
        l0 = false;
        e = x.toString();
      });
    }
  }

  Future<void> refreshAll() async {
    await loadSummary();
    await loadRows(reset: true);
  }

  Future<void> loadSummary() async {
    setState(() {
      l1 = true;
      e = null;
    });

    try {
      final aid = _activeAuditId();
      final r = await widget.api.detectionSummary(auditId: aid);
      setState(() {
        sum = r;
        l1 = false;
      });
    } catch (x) {
      setState(() {
        e = x.toString();
        l1 = false;
      });
    }
  }

  Future<void> loadRows({bool reset = false}) async {
    if (reset) {
      page = 0;
      sel = null;
    }

    setState(() {
      l2 = true;
      e = null;
    });

    try {
      final aid = _activeAuditId();

      final lim = aid == null ? pageSize : 5000;
      final off = aid == null ? page * pageSize : 0;

      final r = await widget.api.detectionResults(
        limit: lim,
        offset: off,
        onlyAnomalies: onlyA,
        minRisk: minR,
        q: q.text.trim(),
        sort: sort,
        auditId: aid,
      );

      final it = (r['items'] as List?) ?? [];
      var list = it.map((x) => Map<String, dynamic>.from(x as Map)).toList();

      if (aid != null) {
        list = list.where((x) => (x['audit_id']?.toString() == aid)).toList();
      }

      setState(() {
        rows = list;
        total = aid == null ? ((r['total'] ?? list.length) as int) : list.length;
        l2 = false;
      });
    } catch (x) {
      setState(() {
        e = x.toString();
        l2 = false;
      });
    }
  }

  Future<void> runDetection() async {
    setState(() {
      runOut = null;
      e = null;
    });

    try {
      final aid = _activeAuditId();
      final r = await widget.api.runDetection();

      setState(() => runOut = r);
      await refreshAll();
      if (widget.autoRun) widget.onAutoRunDone?.call();
    } catch (x) {
      setState(() => runOut = {"status": "error", "message": x.toString()});
    }
  }

  String _s(dynamic v, [String d = '—']) {
    final x = v?.toString();
    if (x == null || x.isEmpty || x == 'null') return d;
    return x;
  }

  Color _riskColor(double r) {
    if (r >= 75) return Colors.red;
    if (r >= 50) return Colors.orange;
    if (r >= 25) return Colors.amber;
    return Colors.green;
  }

  TextStyle _mono(double s, {FontWeight? w}) =>
      TextStyle(fontFamily: 'monospace', fontSize: s, fontWeight: w);

  ShapeBorder _cardShape(ColorScheme cs) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: cs.outlineVariant.withOpacity(0.75)),
    );
  }

  Widget _chip(String t, {Color? bg, Color? fg, IconData? i}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (fg ?? Colors.black).withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (i != null) ...[
            Icon(i, size: 14, color: fg?.withOpacity(0.9)),
            const SizedBox(width: 6),
          ],
          Text(
            t,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String t, String v, {Color? c, IconData? i}) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Card(
        elevation: 0,
        shape: _cardShape(cs),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (c ?? cs.primary).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(i ?? Icons.analytics_outlined, color: (c ?? cs.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t, style: TextStyle(color: cs.onSurface.withOpacity(0.65))),
                    const SizedBox(height: 6),
                    Text(
                      v,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: c ?? cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bucketBars() {
    final cs = Theme.of(context).colorScheme;
    final s = sum;
    if (s == null || s['status'] != 'ok') return const SizedBox.shrink();
    final b = (s['buckets'] as List?) ?? [];
    if (b.isEmpty) return const SizedBox.shrink();

    int maxC = 1;
    for (final x in b) {
      final c = (x as Map)['count'] ?? 0;
      if (c is int && c > maxC) maxC = c;
    }

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
                Icon(Icons.stacked_bar_chart, color: cs.primary),
                const SizedBox(width: 10),
                const Text('Risk Buckets', style: TextStyle(fontWeight: FontWeight.w900)),
                const Spacer(),
                _chip(
                  'auto summary',
                  bg: cs.surfaceVariant.withOpacity(0.45),
                  fg: cs.onSurface.withOpacity(0.75),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final x in b)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: Text(
                        _s((x as Map)['label']),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: ((x['count'] as int?) ?? 0) / maxC,
                          minHeight: 10,
                          backgroundColor: cs.outlineVariant.withOpacity(0.35),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${x['count'] ?? 0}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topList(String title, List list, String keyLabel, String keyCount) {
    final cs = Theme.of(context).colorScheme;
    if (list.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: _cardShape(cs),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (final x in list.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _s((x as Map)[keyLabel]),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurface.withOpacity(0.85)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.7)),
                      ),
                      child: Text(
                        '${x[keyCount] ?? 0}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailBox() {
    if (sel == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final s = const JsonEncoder.withIndent('  ').convert(sel);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
      ),
      child: SelectableText(s, style: _mono(12)),
    );
  }

  Widget _timeCell(Map<String, dynamic> r) {
    final cs = Theme.of(context).colorScheme;

    final ts = r['timestamp'];
    final x = ts?.toString();
    final unknown = x == null || x.isEmpty || x == 'null';
    if (!unknown) return Text(x);

    return Row(
      children: [
        Text('Unknown', style: TextStyle(color: cs.onSurface.withOpacity(0.8))),
        const SizedBox(width: 8),
        _chip(
          'parse incomplete',
          bg: cs.surfaceVariant.withOpacity(0.45),
          fg: cs.onSurface.withOpacity(0.65),
          i: Icons.warning_amber_rounded,
        ),
      ],
    );
  }

  Widget _table({required bool bounded}) {
    final cs = Theme.of(context).colorScheme;

    if (l2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: const LinearProgressIndicator(minHeight: 6),
      );
    }

    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_off, color: cs.onSurface.withOpacity(0.55)),
            const SizedBox(width: 10),
            Text(
              'No rows. Run detection or reduce filters.',
              style: TextStyle(color: cs.onSurface.withOpacity(0.75)),
            ),
          ],
        ),
      );
    }

    final table = DataTable(
      headingTextStyle: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface.withOpacity(0.85)),
      dataTextStyle: TextStyle(color: cs.onSurface.withOpacity(0.85)),
      dividerThickness: 0.8,
      headingRowColor: MaterialStatePropertyAll(cs.surfaceVariant.withOpacity(0.35)),
      dataRowColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) return cs.primary.withOpacity(0.10);
        if (states.contains(MaterialState.hovered)) return cs.surfaceVariant.withOpacity(0.38);
        return null;
      }),
      columns: const [
        DataColumn(label: Text('Time')),
        DataColumn(label: Text('Audit')),
        DataColumn(label: Text('User')),
        DataColumn(label: Text('IP')),
        DataColumn(label: Text('Action')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Risk')),
        DataColumn(label: Text('Anom')),
      ],
      rows: rows.map((r) {
        final rr = double.tryParse('${r['risk_score']}') ?? 0;
        final an = (r['is_anomaly'] ?? 0).toString() == '1';
        final aid = _s(r['audit_id']);
        final aidShort = aid.length > 10 ? '${aid.substring(0, 8)}…' : aid;

        final rc = _riskColor(rr);

        return DataRow(
          selected: sel == r,
          onSelectChanged: (_) => setState(() => sel = r),
          cells: [
            DataCell(_timeCell(r)),
            DataCell(Text(aidShort)),
            DataCell(Text(_s(r['user']))),
            DataCell(Text(_s(r['source_ip']))),
            DataCell(Text(_s(r['action']))),
            DataCell(Text(_s(r['status']))),
            DataCell(
              Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: rc, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(rr.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            DataCell(
              _chip(
                an ? 'YES' : 'NO',
                bg: an ? Colors.red.withOpacity(0.10) : cs.surfaceVariant.withOpacity(0.35),
                fg: an ? Colors.red : cs.onSurface.withOpacity(0.75),
                i: an ? Icons.report_gmailerrorred_rounded : Icons.check_circle_outline,
              ),
            ),
          ],
        );
      }).toList(),
    );

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: bounded
            ? Scrollbar(
          controller: _vCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _vCtrl,
            child: Scrollbar(
              controller: _hCtrl,
              thumbVisibility: true,
              notificationPredicate: (n) => n.depth == 1,
              child: SingleChildScrollView(
                controller: _hCtrl,
                scrollDirection: Axis.horizontal,
                child: table,
              ),
            ),
          ),
        )
            : Scrollbar(
          controller: _hCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _hCtrl,
            scrollDirection: Axis.horizontal,
            child: table,
          ),
        ),
      ),
    );
  }

  Widget _scopeControl({required bool wide}) {
    final cs = Theme.of(context).colorScheme;
    final items = ingests;

    Widget pickDrop() {
      final ids = items.map((x) => x['audit_id']?.toString()).whereType<String>().toList();

      if (ids.isEmpty) {
        return const SizedBox(width: 260, child: Text('No ingests yet.'));
      }

      pickId ??= ids.first;

      return SizedBox(
        width: wide ? 360 : double.infinity,
        height: 46,
        child: DropdownButtonFormField<String>(
          value: pickId,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            labelText: 'Pick audit_id',
            filled: true,
            fillColor: cs.surfaceVariant.withOpacity(0.35),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: ids.map((id) {
            final row = items.firstWhere(
                  (z) => z['audit_id']?.toString() == id,
              orElse: () => const {},
            );
            final fn = row['filename']?.toString() ?? '';
            final tm = row['upload_time']?.toString() ?? '';
            final label = '${id.substring(0, 8)}…  $fn  ${tm.isEmpty ? '' : '($tm)'}';
            return DropdownMenuItem(value: id, child: Text(label, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (v) async {
            if (v == null) return;
            setState(() => pickId = v);
            await refreshAll();
          },
        ),
      );
    }

    final scopeDrop = SizedBox(
      width: wide ? 230 : double.infinity,
      height: 46,
      child: DropdownButtonFormField<String>(
        value: scope,
        isDense: true,
        decoration: InputDecoration(
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: true,
          fillColor: cs.surfaceVariant.withOpacity(0.35),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All uploads')),
          DropdownMenuItem(value: 'latest', child: Text('Latest upload')),
          DropdownMenuItem(value: 'pick', child: Text('Pick audit_id')),
        ],
        onChanged: (v) async {
          if (v == null) return;
          setState(() => scope = v);
          await refreshAll();
        },
      ),
    );

    final reloadBtn = SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: l0
            ? null
            : () async {
          await _loadIngests();
          await refreshAll();
        },
        icon: const Icon(Icons.sync),
        label: const Text('Reload ingests'),
        style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
      ),
    );

    final latestText = (scope == 'latest')
        ? Text(
      latestId == null ? 'Latest: —' : 'Latest: ${latestId!.substring(0, 8)}…',
      style: TextStyle(
        color: cs.onSurface.withOpacity(0.65),
        fontWeight: FontWeight.w600,
      ),
    )
        : const SizedBox.shrink();

    final wrap = Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_outlined, color: cs.primary),
            const SizedBox(width: 10),
            const Text('Evidence scope', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        scopeDrop,
        if (scope == 'latest') latestText,
        if (scope == 'pick') pickDrop(),
        reloadBtn,
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
      ),
      child: wide
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: wrap)
          : wrap,
    );
  }

  Widget _filters() {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: _cardShape(cs),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: q,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search user / IP / action',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: cs.surfaceVariant.withOpacity(0.35),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onSubmitted: (_) => loadRows(reset: true),
              ),
            ),
            FilterChip(
              selected: onlyA,
              label: const Text('Only anomalies'),
              onSelected: (v) {
                setState(() => onlyA = v);
                loadRows(reset: true);
              },
              showCheckmark: true,
              selectedColor: Colors.red.withOpacity(0.12),
              checkmarkColor: Colors.red,
              side: BorderSide(color: cs.outlineVariant.withOpacity(0.75)),
            ),
            Container(
              width: 320,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.30),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
              ),
              child: Row(
                children: [
                  Text(
                    'Min risk',
                    style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface.withOpacity(0.75)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Slider(
                      value: minR,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: minR.toStringAsFixed(0),
                      onChanged: (v) => setState(() => minR = v),
                      onChangeEnd: (_) => loadRows(reset: true),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      minR.toStringAsFixed(0),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                value: sort,
                isDense: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: cs.surfaceVariant.withOpacity(0.35),
                ),
                items: const [
                  DropdownMenuItem(value: 'risk_desc', child: Text('Sort: Risk')),
                  DropdownMenuItem(value: 'time_desc', child: Text('Sort: Newest')),
                  DropdownMenuItem(value: 'time_asc', child: Text('Sort: Oldest')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => sort = v);
                  loadRows(reset: true);
                },
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => loadRows(reset: true),
              icon: const Icon(Icons.tune),
              label: const Text('Apply'),
            ),
            const SizedBox(width: 4),
            OutlinedButton(
              onPressed: (scope != 'all' || page <= 0)
                  ? null
                  : () {
                setState(() => page -= 1);
                loadRows();
              },
              child: const Text('Prev'),
            ),
            OutlinedButton(
              onPressed: (scope != 'all' || ((page + 1) * pageSize) >= total)
                  ? null
                  : () {
                setState(() => page += 1);
                loadRows();
              },
              child: const Text('Next'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runOutBoxCard() {
    final cs = Theme.of(context).colorScheme;
    final s = const JsonEncoder.withIndent('  ').convert(runOut);

    return Card(
      elevation: 0,
      shape: _cardShape(cs),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.terminal_outlined, color: cs.primary),
                const SizedBox(width: 10),
                const Text('Last Run Output', style: TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
              ),
              child: SelectableText(s, style: _mono(12)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.of(context).size.width;
    final narrow = w < 1100;

    final s = sum;
    final okk = s != null && s['status'] == 'ok';
    final t = okk ? (s['total'] ?? 0).toString() : '—';
    final a = okk ? (s['anomalies'] ?? 0).toString() : '—';

    final topU = okk ? ((s['top_users'] as List?) ?? []) : const [];
    final topI = okk ? ((s['top_ips'] as List?) ?? []) : const [];

    final header = narrow
        ? Column(
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
              child: Icon(Icons.bug_report_outlined, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  widget.scopeLabel == null || widget.scopeLabel!.trim().isEmpty
                      ? 'Anomaly detection & risk scoring'
                      : widget.scopeLabel!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: l0 || l1 || l2 ? null : refreshAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: l0 || l1 || l2 ? null : runDetection,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Detection'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _scopeControl(wide: false),
      ],
    )
        : Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.bug_report_outlined, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              widget.scopeLabel == null || widget.scopeLabel!.trim().isEmpty
                  ? 'Anomaly detection & risk scoring'
                  : widget.scopeLabel!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(0.65),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(child: Align(alignment: Alignment.center, child: _scopeControl(wide: true))),
        const SizedBox(width: 14),
        OutlinedButton.icon(
          onPressed: l0 || l1 || l2 ? null : refreshAll,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: l0 || l1 || l2 ? null : runDetection,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Run Detection'),
        ),
      ],
    );

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
            header,
            const SizedBox(height: 12),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: e == null
                  ? const SizedBox.shrink()
                  : Container(
                key: ValueKey(e),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
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
                        e!,
                        style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Row(
              children: [
                _kpi('Total Rows', t, i: Icons.table_rows_outlined),
                const SizedBox(width: 12),
                _kpi('Anomalies', a, c: Colors.red, i: Icons.report_gmailerrorred_outlined),
                const SizedBox(width: 12),
                _kpi('Shown', '${rows.length}', i: Icons.filter_alt_outlined),
              ],
            ),

            const SizedBox(height: 12),
            if (l0 || l1)
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(minHeight: 6),
              ),

            const SizedBox(height: 12),

            Expanded(
              child: narrow
                  ? ListView(
                children: [
                  _bucketBars(),
                  const SizedBox(height: 12),
                  _topList('Top Users (anomalies)', topU, 'user', 'count'),
                  const SizedBox(height: 12),
                  _topList('Top IPs (anomalies)', topI, 'ip', 'count'),
                  const SizedBox(height: 12),
                  _filters(),
                  const SizedBox(height: 12),
                  _table(bounded: false),
                  const SizedBox(height: 12),
                  if (sel != null) _detailBox(),
                  if (sel != null) const SizedBox(height: 12),
                  if (runOut != null) _runOutBoxCard(),
                ],
              )
                  : Row(
                children: [
                  SizedBox(
                    width: 390,
                    child: ListView(
                      children: [
                        _bucketBars(),
                        const SizedBox(height: 12),
                        _topList('Top Users (anomalies)', topU, 'user', 'count'),
                        const SizedBox(height: 12),
                        _topList('Top IPs (anomalies)', topI, 'ip', 'count'),
                        const SizedBox(height: 12),
                        if (runOut != null) _runOutBoxCard(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _filters(),
                        const SizedBox(height: 12),
                        Expanded(child: _table(bounded: true)),
                        const SizedBox(height: 12),
                        if (sel != null)
                          SizedBox(height: 220, child: _detailBox()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}