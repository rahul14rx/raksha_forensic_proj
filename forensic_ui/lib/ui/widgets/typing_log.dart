import 'dart:async';
import 'package:flutter/material.dart';

class LogItem {
  final String t;
  bool done;
  LogItem(this.t, {this.done = false});
}

class TypingLog extends StatefulWidget {
  final List<LogItem> items;
  const TypingLog({super.key, required this.items});

  @override
  State<TypingLog> createState() => _TypingLogState();
}

class _TypingLogState extends State<TypingLog> {
  final _sc = ScrollController();

  @override
  void didUpdateWidget(covariant TypingLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) _sc.jumpTo(_sc.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _sc,
      child: ListView.builder(
        controller: _sc,
        itemCount: widget.items.length,
        itemBuilder: (ctx, i) {
          final x = widget.items[i];
          if (x.done) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(x.t),
            );
          }
          return _TypingLine(
            key: ValueKey('typing_${i}_${x.t}'),
            text: x.t,
            onDone: () {
              if (!mounted) return;
              setState(() => x.done = true);
            },
          );
        },
      ),
    );
  }
}

class _TypingLine extends StatefulWidget {
  final String text;
  final VoidCallback onDone;
  const _TypingLine({super.key, required this.text, required this.onDone});

  @override
  State<_TypingLine> createState() => _TypingLineState();
}

class _TypingLineState extends State<_TypingLine> {
  int n = 0;
  Timer? tm;

  @override
  void initState() {
    super.initState();
    tm = Timer.periodic(const Duration(milliseconds: 14), (_) {
      if (!mounted) return;
      if (n >= widget.text.length) {
        tm?.cancel();
        widget.onDone();
        return;
      }
      setState(() => n++);
    });
  }

  @override
  void dispose() {
    tm?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.text.substring(0, n.clamp(0, widget.text.length));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(s),
    );
  }
}
