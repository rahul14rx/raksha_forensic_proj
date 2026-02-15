import 'package:flutter/material.dart';

import 'core/api.dart';
import 'ui/pages/chain_custody_page.dart';
import 'ui/pages/dashboard_page.dart';
import 'ui/pages/detection_page.dart';
import 'ui/pages/features_page.dart';
import 'ui/pages/ingest_integrity.dart';
import 'ui/pages/reports_page.dart';

void main() {
  runApp(const App());
}

enum ScopeMode { all, latest, pick }

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const String new_base = 'https://raksha-forenix-api.onrender.com';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Forensic UI',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: Shell(api: Api(new_base)),
    );
  }
}

class Shell extends StatefulWidget {
  final Api api;
  const Shell({super.key, required this.api});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  late final TabController _tc;

  int i = 0;

  ScopeMode sm = ScopeMode.latest;
  List<Map<String, dynamic>> ing = [];
  bool li = false;
  String? ie;
  String? pickId;

  bool autoF = false;
  bool autoD = false;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 6, vsync: this, initialIndex: i);
    _tc.addListener(() {
      if (!_tc.indexIsChanging && i != _tc.index) {
        setState(() => i = _tc.index);
      }
    });
    loadIngests();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> loadIngests() async {
    if (li) return;
    setState(() {
      li = true;
      ie = null;
    });
    try {
      final r = await widget.api.getJson('/api/ingest/list');
      final it = (r['items'] as List?) ?? [];
      final xs = it.map((x) => Map<String, dynamic>.from(x as Map)).toList();

      xs.sort((a, b) {
        final ta = DateTime.tryParse(a['upload_time']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = DateTime.tryParse(b['upload_time']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });

      if (!mounted) return;
      setState(() {
        ing = xs;
        li = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        ie = e.toString();
        li = false;
      });
    }
  }

  String? get latestId {
    if (ing.isEmpty) return null;
    final v = ing.first['audit_id'];
    return (v == null) ? null : v.toString();
  }

  String? get effId {
    if (sm == ScopeMode.all) return null;
    if (sm == ScopeMode.latest) return latestId;
    return pickId ?? latestId;
  }

  String get scopeLabel {
    if (sm == ScopeMode.all) return 'All uploads';
    if (sm == ScopeMode.latest) return 'Latest upload';
    return 'Picked audit_id';
  }

  void _setTab(int idx) {
    if (idx < 0 || idx >= 6) return;
    setState(() => i = idx);
    if (_tc.index != idx) _tc.animateTo(idx);
  }

  void goFeatures({bool auto = false}) {
    setState(() => autoF = auto);
    _setTab(3);
  }

  void goDetect({bool auto = false}) {
    setState(() => autoD = auto);
    _setTab(4);
  }

  void goChain(String auditId) {
    setState(() {
      sm = ScopeMode.pick;
      pickId = auditId;
    });
    _setTab(2);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final id = effId;

    final pages = [
      DashboardPage(api: widget.api),
      IngestIntegrityPage(
        api: widget.api,
        onIngested: (x) async {
          await loadIngests();
          if (!mounted) return;
          setState(() {
            sm = ScopeMode.latest;
            pickId = x;
          });
        },
        onDoneToChain: (x) => goChain(x),
      ),
      ChainCustodyPage(
        api: widget.api,
        initialAuditId: id,
        onNextFeatures: () => goFeatures(auto: true),
      ),
      FeaturesPage(
        key: ValueKey('features_${id ?? "all"}_${autoF ? "auto" : "manual"}'),
        api: widget.api,
        auditId: id,
        scopeLabel: scopeLabel,
        autoRun: autoF,
        onAutoRunDone: () => setState(() => autoF = false),
        onNextDetect: () => goDetect(auto: true),
      ),
      DetectionPage(
        api: widget.api,
        auditId: id,
        scopeLabel: scopeLabel,
        autoRun: autoD,
        onAutoRunDone: () => setState(() => autoD = false),
      ),
     // const Center(child: Text('Results (next)')),
      ReportsPage(api: widget.api),
    ];

    return Scaffold(
      body: Column(
        children: [
          _TopNavBar(
            controller: _tc,
            selectedIndex: i,
            onTab: (x) => _setTab(x),
            title: 'Raksha Forenix', 
            rightHint: null,
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.primary.withOpacity(0.06),
                    cs.surface,
                  ],
                ),
              ),
              child: IndexedStack(
                index: i,
                children: pages,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopNavBar extends StatelessWidget {
  final TabController controller;
  final int selectedIndex;
  final ValueChanged<int> onTab;
  final String title;
  final String? subtitle;
  final String? rightHint;

  const _TopNavBar({
    required this.controller,
    required this.selectedIndex,
    required this.onTab,
    required this.title,
    this.subtitle,
    this.rightHint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      elevation: 0,
      color: cs.surface.withOpacity(0.92),
      child: Container(
        padding: const EdgeInsets.only(top: 10, bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.7)),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, c) {
              final side = c.maxWidth >= 980 ? 240.0 : 150.0;

              return Row(
                children: [
                  SizedBox(
                    width: side,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: cs.primary.withOpacity(0.18),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(5.0), // Adjust padding as needed to fit image well
                              child: Image.asset(
                                'assets/emblem.png', // Ensure this matches your file name
                               // color: cs.primary,   // Tints the image to match the theme. Remove this line if your image already has colors you want to keep.
                                fit: BoxFit.contain,
                              ),
                            ),
                            // ----------------------------------------
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15.5,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: AnimatedBuilder(
                          animation: controller,
                          builder: (_, __) {
                            final sel = controller.index;
                            return TabBar(
                              controller: controller,
                              isScrollable: true,
                              tabAlignment: TabAlignment.center,
                              onTap: onTab,
                              dividerColor: Colors.transparent,
                              splashBorderRadius: BorderRadius.circular(999),
                              labelPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                              overlayColor: MaterialStatePropertyAll(
                                cs.primary.withOpacity(0.06),
                              ),
                              indicatorSize: TabBarIndicatorSize.label,
                              indicator: DashedUnderlineIndicator(
                                borderSide: BorderSide(
                                  color: cs.primary,
                                  width: 2.4,
                                ),
                                dashWidth: 7,
                                dashSpace: 5,
                                inset: 10,
                              ),
                              tabs: [
                                _NavTab(
                                  label: 'Dashboard',
                                  icon: Icons.dashboard_outlined,
                                  active: sel == 0,
                                ),
                                _NavTab(
                                  label: 'Ingest',
                                  icon: Icons.upload_file_outlined,
                                  active: sel == 1,
                                ),
                                _NavTab(
                                  label: 'Chain',
                                  icon: Icons.link_outlined,
                                  active: sel == 2,
                                ),
                                _NavTab(
                                  label: 'Features',
                                  icon: Icons.tune_outlined,
                                  active: sel == 3,
                                ),
                                _NavTab(
                                  label: 'Detect',
                                  icon: Icons.warning_amber_outlined,
                                  active: sel == 4,
                                ),
                                // _NavTab(
                                //   label: 'Results',
                                //   icon: Icons.table_chart_outlined,
                                //   active: sel == 5,
                                // ),
                                _NavTab(
                                  label: 'Reports',
                                  icon: Icons.picture_as_pdf_outlined,
                                  active: sel == 5,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                    width: side,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: rightHint == null
                            ? const SizedBox.shrink()
                            : Text(
                          rightHint!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tab(
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        scale: active ? 1.06 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: const BoxDecoration(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? cs.primary
                    : cs.onSurface.withOpacity(0.65),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.8,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  color: active
                      ? cs.primary
                      : cs.onSurface.withOpacity(0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashedUnderlineIndicator extends Decoration {
  final BorderSide borderSide;
  final double dashWidth;
  final double dashSpace;
  final double inset;

  const DashedUnderlineIndicator({
    required this.borderSide,
    this.dashWidth = 7,
    this.dashSpace = 5,
    this.inset = 10,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _DashedUnderlinePainter(this, onChanged);
  }
}

class _DashedUnderlinePainter extends BoxPainter {
  final DashedUnderlineIndicator d;

  _DashedUnderlinePainter(this.d, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final sz = configuration.size;
    if (sz == null) return;

    final paint = d.borderSide.toPaint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final y = offset.dy + sz.height - (d.borderSide.width / 2);
    final startX = offset.dx + d.inset;
    final endX = offset.dx + sz.width - d.inset;

    if (endX <= startX) return;

    double x = startX;
    while (x < endX) {
      final x2 = (x + d.dashWidth) > endX ? endX : (x + d.dashWidth);
      canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
      x = x2 + d.dashSpace;
    }
  }
}