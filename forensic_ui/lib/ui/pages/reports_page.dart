import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../../core/api.dart'; 

class ReportsPage extends StatefulWidget {
  final Api api;
  const ReportsPage({super.key, required this.api});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final String new_id = 'ghostwriter-report-engine';
  final String new_url = 'https://raksha-forenix-api.onrender.com/api/reports/ghostwriter';

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(
      new_id,
      (int new_id) => html.IFrameElement()
        ..src = new_url
        ..style.border = 'none'
        ..style.height = '100%'
        ..style.width = '100%',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF00FF41), width: 1), 
        ),
        child: Column(
          children: [
            Expanded(
              child: HtmlElementView(viewType: new_id),
            ),
          ],
        ),
      ),
    );
  }
}