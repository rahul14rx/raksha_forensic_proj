import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/api.dart';

class DashboardPage extends StatefulWidget {
  final Api api;
  const DashboardPage({super.key, required this.api});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? s;
  Map<String, dynamic>? t;
  Map<String, dynamic>? sev;
  List<dynamic> recent = [];
  bool l = true;
  String? e;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      l = true;
      e = null;
    });

    try {
      final a = await widget.api.dashboardSummary();
      final b = await widget.api.dashboardTimeline();
      final c = await widget.api.dashboardSeverity();
      final d = await widget.api.dashboardRecentUploads();

      setState(() {
        s = a;
        t = b;
        sev = c;
        recent = (d['items'] as List?) ?? [];
        l = false;
      });
    } catch (x) {
      setState(() {
        e = x.toString();
        l = false;
      });
    }
  }

  String _fmtTs(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    return iso.replaceFirst('T', ' ').split('.').first;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: cs.outlineVariant.withOpacity(0.75)),
    );

    final total = (s?['total_events'] ?? 0) as int;
    final crit = (s?['critical_threats'] ?? 0) as int;
    final earliest = _fmtTs(s?['earliest_log'] as String?);
    final latest = _fmtTs(s?['latest_log'] as String?);

    final series = ((t?['series'] as List?) ?? List.filled(24, 0)).cast<int>();
    final c = (sev?['critical'] ?? 0) as int;
    final w = (sev?['warning'] ?? 0) as int;
    final i = (sev?['info'] ?? 0) as int;

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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: l ? null : _load,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),


            const SizedBox(height: 12),

            if (l)
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const LinearProgressIndicator(minHeight: 6),
              ),

            if (e != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('Error: $e',
                    style: TextStyle(
                        color: cs.error, fontWeight: FontWeight.w700)),
              ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Total Events',
                    value: _fmtNum(total),
                    shape: cardShape,
                    bg: cs.surfaceVariant.withOpacity(0.20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Critical Threats',
                    value: _fmtNum(crit),
                    danger: true,
                    shape: cardShape,
                    bg: cs.surfaceVariant.withOpacity(0.20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Earliest Log',
                    value: earliest,
                    mono: true,
                    shape: cardShape,
                    bg: cs.surfaceVariant.withOpacity(0.20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Latest Log',
                    value: latest,
                    mono: true,
                    shape: cardShape,
                    bg: cs.surfaceVariant.withOpacity(0.20),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Card(
                      elevation: 0,
                      shape: cardShape,
                      color: cs.surfaceVariant.withOpacity(0.18),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Event Timeline',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                              'Events per hour (00:00–23:00)',
                              style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.65),
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Container(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: cs.surface.withOpacity(0.40),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: cs.outlineVariant
                                          .withOpacity(0.70)),
                                ),
                                child: _LineChart(series: series),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 0,
                      shape: cardShape,
                      color: cs.surfaceVariant.withOpacity(0.18),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Severity Distribution',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                              'Source: ${(sev?['source'] ?? '—')}',
                              style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.65),
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cs.surface.withOpacity(0.40),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: cs.outlineVariant
                                          .withOpacity(0.70)),
                                ),
                                child: _PieChart(c: c, w: w, i: i),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _LegendRow(label: 'Critical', value: c),
                            _LegendRow(label: 'Warning', value: w),
                            _LegendRow(label: 'Info', value: i),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 0,
                      shape: cardShape,
                      color: cs.surfaceVariant.withOpacity(0.18),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Recent Uploads',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cs.surface.withOpacity(0.40),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: cs.outlineVariant
                                          .withOpacity(0.70)),
                                ),
                                child: recent.isEmpty
                                    ? Center(
                                  child: Text('No uploads yet',
                                      style: TextStyle(
                                          color: cs.onSurface
                                              .withOpacity(0.70),
                                          fontWeight: FontWeight.w600)),
                                )
                                    : ListView.separated(
                                  itemCount: min(20, recent.length),
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: cs.outlineVariant
                                        .withOpacity(0.65),
                                  ),
                                  itemBuilder: (_, x) {
                                    final r =
                                    recent[x] as Map<String, dynamic>;
                                    final fn =
                                    (r['filename'] ?? '—').toString();
                                    final ts =
                                    _fmtTs(r['upload_time'] as String?);
                                    final st =
                                    (r['status'] ?? '—').toString();
                                    final id =
                                    (r['audit_id'] ?? '').toString();
                                    return ListTile(
                                      dense: true,
                                      title: Text(fn,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight:
                                              FontWeight.w700)),
                                      subtitle: Text(
                                        '$ts • $st',
                                        style: TextStyle(
                                            color: cs.onSurface
                                                .withOpacity(0.65),
                                            fontWeight: FontWeight.w600),
                                      ),
                                      trailing: Text(
                                        id.isEmpty
                                            ? ''
                                            : id.substring(
                                            0, min(8, id.length)),
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: cs.onSurface
                                                .withOpacity(0.75)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          ],
                        ),
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

  static String _fmtNum(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int x = 0; x < s.length; x++) {
      final idx = s.length - x;
      b.write(s[x]);
      if (idx > 1 && idx % 3 == 1) b.write(',');
    }
    return b.toString();
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final bool danger;
  final bool mono;

  final ShapeBorder? shape;
  final Color? bg;

  const _StatCard({
    required this.title,
    required this.value,
    this.danger = false,
    this.mono = false,
    this.shape,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = danger ? Colors.red : cs.primary;

    return Card(
      elevation: 0,
      shape: shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: cs.outlineVariant.withOpacity(0.75)),
          ),
      color: bg ?? cs.surfaceVariant.withOpacity(0.18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: danger ? Colors.red : cs.onSurface.withOpacity(0.70),
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: mono ? 14 : 26,
                      fontWeight: FontWeight.w900,
                      fontFamily: mono ? 'monospace' : null,
                      color: cs.onSurface.withOpacity(0.88),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                danger ? Icons.warning_amber_rounded : Icons.circle_outlined,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final int value;
  const _LegendRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.80))),
          ),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _LineChart extends StatefulWidget {
  final List<int> series;
  const _LineChart({required this.series});

  @override
  State<_LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<_LineChart> {
  int? hi;
  Offset? pos;

  void _clear() => setState(() {
    hi = null;
    pos = null;
  });

  void _updateHover(Offset p, Size size) {
    const mL = 36.0;
    const mB = 24.0;
    final w = size.width - mL - 8;
    final h = size.height - 8 - mB;

    final inX = p.dx >= mL && p.dx <= (mL + w);
    final inY = p.dy >= 8 && p.dy <= (8 + h);
    if (!inX || !inY) {
      _clear();
      return;
    }

    final xNorm = ((p.dx - mL) / w).clamp(0.0, 1.0);
    final idx = (xNorm * 23).round().clamp(0, 23);

    setState(() {
      hi = idx;
      pos = p;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (_, c) {
        final size = Size(c.maxWidth, c.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _updateHover(d.localPosition, size),
          onTapCancel: _clear,
          child: MouseRegion(
            onExit: (_) => _clear(),
            onHover: (e) => _updateHover(e.localPosition, size),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LineChartPainter(
                      widget.series,
                      lineColor: cs.primary,
                      gridColor: cs.outlineVariant.withOpacity(0.55),
                      hoverIndex: hi,
                    ),
                  ),
                ),
                if (hi != null) _LineHoverTooltip(series: widget.series, index: hi!, lineColor: cs.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LineHoverTooltip extends StatelessWidget {
  final List<int> series;
  final int index;
  final Color lineColor;

  const _LineHoverTooltip({
    required this.series,
    required this.index,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final v = series[index];
    final hh = index.toString().padLeft(2, '0');

    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 10, top: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: lineColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                '$hh:00',
                style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface.withOpacity(0.9)),
              ),
              const SizedBox(width: 10),
              Text(
                'Events: $v',
                style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface.withOpacity(0.75)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> s;
  final Color lineColor;
  final Color gridColor;
  final int? hoverIndex;

  _LineChartPainter(
      this.s, {
        required this.lineColor,
        required this.gridColor,
        required this.hoverIndex,
      });

  @override
  void paint(Canvas canvas, Size size) {
    final g = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gridColor;

    final mL = 36.0;
    final mB = 24.0;
    final w = size.width - mL - 8;
    final h = size.height - 8 - mB;

    for (int i = 0; i <= 6; i++) {
      final y = 8 + h * (i / 6);
      canvas.drawLine(Offset(mL, y), Offset(mL + w, y), g);
    }
    for (int i = 0; i <= 11; i++) {
      final x = mL + w * (i / 11);
      canvas.drawLine(Offset(x, 8), Offset(x, 8 + h), g);
    }

    final maxV = max(1, s.fold<int>(0, (a, b) => max(a, b)));

    final pts = <Offset>[];
    for (int i = 0; i < 24; i++) {
      final x = mL + (w * (i / 23));
      final y = 8 + h - (h * (s[i] / maxV));
      pts.add(Offset(x, y));
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = lineColor;

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withOpacity(0.22),
          lineColor.withOpacity(0.02),
        ],
      ).createShader(Rect.fromLTWH(mL, 8, w, h));

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }

    final area = Path.from(path)
      ..lineTo(pts.last.dx, 8 + h)
      ..lineTo(pts.first.dx, 8 + h)
      ..close();

    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);

    final dot = Paint()..color = lineColor.withOpacity(0.9);
    for (int i = 0; i < pts.length; i++) {
      final r = (hoverIndex == i) ? 5.2 : 3.2;
      canvas.drawCircle(pts[i], r, dot);
      if (hoverIndex == i) {
        final ring = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = lineColor.withOpacity(0.35);
        canvas.drawCircle(pts[i], 9.0, ring);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) {
    return old.s != s ||
        old.lineColor != lineColor ||
        old.gridColor != gridColor ||
        old.hoverIndex != hoverIndex;
  }
}

class _PieChart extends StatefulWidget {
  final int c, w, i;
  const _PieChart({required this.c, required this.w, required this.i});

  @override
  State<_PieChart> createState() => _PieChartState();
}

class _PieChartState extends State<_PieChart> {
  int? hi;

  void _setHover(Offset p, Size size) {
    final total = max(1, widget.c + widget.w + widget.i);
    final r = min(size.width, size.height) * 0.36;
    final center = Offset(size.width / 2, size.height / 2);

    final dx = p.dx - center.dx;
    final dy = p.dy - center.dy;
    final dist = sqrt(dx * dx + dy * dy);

    if (dist > r) {
      setState(() => hi = null);
      return;
    }

    final parts = [widget.c, widget.w, widget.i];
    final sweeps = parts.map((v) => (v / total) * 2 * pi).toList();

    var ang = atan2(dy, dx);
    ang -= (-pi / 2);
    while (ang < 0) ang += 2 * pi;
    while (ang >= 2 * pi) ang -= 2 * pi;

    double acc = 0;
    for (int k = 0; k < sweeps.length; k++) {
      final sw = sweeps[k];
      if (ang >= acc && ang < acc + sw) {
        setState(() => hi = k);
        return;
      }
      acc += sw;
    }

    setState(() => hi = null);
  }

  void _clear() => setState(() => hi = null);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final labels = const ['Critical', 'Warning', 'Info'];
    final values = [widget.c, widget.w, widget.i];
    final total = max(1, widget.c + widget.w + widget.i);

    return LayoutBuilder(
      builder: (_, c) {
        final size = Size(c.maxWidth, c.maxHeight);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _setHover(d.localPosition, size),
          onTapCancel: _clear,
          child: MouseRegion(
            onExit: (_) => _clear(),
            onHover: (e) => _setHover(e.localPosition, size),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PiePainter(widget.c, widget.w, widget.i, hoverIndex: hi),
                  ),
                ),
                if (hi != null)
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, top: 10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.surface.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.75)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Text(
                          '${labels[hi!]}: ${values[hi!]}  (${((values[hi!] / total) * 100).toStringAsFixed(1)}%)',
                          style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface.withOpacity(0.85)),
                        ),
                      ),
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

class _PiePainter extends CustomPainter {
  final int c, w, i;
  final int? hoverIndex;

  _PiePainter(this.c, this.w, this.i, {required this.hoverIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final total = max(1, c + w + i);
    final r = min(size.width, size.height) * 0.36;
    final center = Offset(size.width / 2, size.height / 2);

    final parts = [
      (c, const Color(0xFFF7B2C4)), // pastel pink
      (w, const Color(0xFFFFD8A8)), // pastel peach
      (i, const Color(0xFFBBD7FF)), // pastel blue
    ];


    double start = -pi / 2;

    for (int idx = 0; idx < parts.length; idx++) {
      final v = parts[idx].$1;
      final col = parts[idx].$2;
      final sweep = (v / total) * 2 * pi;

      final isHover = hoverIndex == idx;
      final rr = isHover ? (r + 6) : r;

      final fill = Paint()
        ..color = isHover ? col.withOpacity(0.95) : col
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: rr),
        start,
        sweep,
        true,
        fill,
      );

      if (isHover) {
        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black.withOpacity(0.10);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: rr),
          start,
          sweep,
          true,
          stroke,
        );
      }

      start += sweep;
    }

  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.c != c ||
        oldDelegate.w != w ||
        oldDelegate.i != i ||
        oldDelegate.hoverIndex != hoverIndex;
  }
}

