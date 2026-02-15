import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class Api {
  final String b;
  final http.Client c;
  Api(this.b, {http.Client? client}) : c = client ?? http.Client();

  Map<String, dynamic> _decode(http.Response r) {
    dynamic v;
    try {
      v = jsonDecode(r.body.isEmpty ? '{}' : r.body);
    } catch (_) {
      v = {'raw': r.body};
    }
    if (v is Map<String, dynamic>) return v;
    return {'data': v};
  }

  Future<Map<String, dynamic>> getJson(String p) async {
    final r = await c.get(Uri.parse('$b$p'));
    if (r.statusCode ~/ 100 == 2) return _decode(r);
    throw Exception('${r.statusCode} ${r.body}');
  }

  Future<Map<String, dynamic>> health() async {
    final r = await c.get(Uri.parse('$b/'));
    if (r.statusCode ~/ 100 == 2) return _decode(r);
    throw Exception('${r.statusCode} ${r.body}');
  }

  Future<Map<String, dynamic>> upload({
    required Uint8List bytes,
    required String name,
    String? u,
  }) async {
    final q = (u != null && u.trim().isNotEmpty)
        ? '?uploader=${Uri.encodeComponent(u.trim())}'
        : '';
    final url = Uri.parse('$b/api/upload-log$q');

    final req = http.MultipartRequest('POST', url);
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));

    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode ~/ 100 == 2) return _decode(res);
    throw Exception('${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> verify(String id) async {
    final r = await c.get(Uri.parse('$b/api/verify/$id'));
    if (r.statusCode ~/ 100 == 2) return _decode(r);
    throw Exception('${r.statusCode} ${r.body}');
  }

  Future<Map<String, dynamic>> verifyChain() async {
    final r = await c.get(Uri.parse('$b/api/verify-chain'));
    if (r.statusCode ~/ 100 == 2) return _decode(r);
    throw Exception('${r.statusCode} ${r.body}');
  }

  Future<Map<String, dynamic>> ledgerList({
    int limit = 200,
    int offset = 0,
    String q = '',
  }) async {
    final qs = 'limit=$limit&offset=$offset&q=${Uri.encodeComponent(q)}';
    final r = await c.get(Uri.parse('$b/api/ledger/list?$qs'));
    if (r.statusCode ~/ 100 == 2) return _decode(r);
    throw Exception('${r.statusCode} ${r.body}');
  }

  Future<Map<String, dynamic>> ledgerItem(String id) async {
    final r = await c.get(Uri.parse('$b/api/ledger/$id'));
    if (r.statusCode ~/ 100 == 2) return _decode(r);
    throw Exception('${r.statusCode} ${r.body}');
  }

  Future<Map<String, dynamic>> dashboardSummary() =>
      getJson('/api/dashboard/summary');
  Future<Map<String, dynamic>> dashboardTimeline() =>
      getJson('/api/dashboard/timeline');
  Future<Map<String, dynamic>> dashboardSeverity() =>
      getJson('/api/dashboard/severity');
  Future<Map<String, dynamic>> dashboardRecentUploads() =>
      getJson('/api/dashboard/recent-uploads');

  Future<Map<String, dynamic>> generateFeatures({String? auditId}) async {
    final qs = (auditId != null && auditId.trim().isNotEmpty)
        ? '?audit_id=${Uri.encodeComponent(auditId.trim())}'
        : '';
    final u = Uri.parse('$b/api/generate-features$qs');
    final r = await c.post(u);
    if (r.statusCode ~/ 100 == 2) return _decode(r);
    throw Exception('${r.statusCode} ${r.body}');
  }

  Future<Map<String, dynamic>> runDetection() async {
    final u = Uri.parse('$b/api/run-detection');
    try {
      final r = await c.post(u);
      if (r.statusCode ~/ 100 == 2) return _decode(r);
      throw Exception('${r.statusCode} ${r.body}');
    } catch (_) {
      final r = await c.get(u);
      if (r.statusCode ~/ 100 == 2) return _decode(r);
      throw Exception('${r.statusCode} ${r.body}');
    }
  }

  Future<Map<String, dynamic>> detectionSummary({String? auditId}) async {
    final qs = (auditId != null && auditId.trim().isNotEmpty)
        ? '?audit_id=${Uri.encodeComponent(auditId.trim())}'
        : '';
    final r = await c.get(Uri.parse('$b/api/detection/summary$qs'));
    if (r.statusCode ~/ 100 == 2) return _decode(r);
    throw Exception('${r.statusCode} ${r.body}');
  }
  Future<Map<String, dynamic>> featuresPreview({
    int limit = 200,
    int offset = 0,
    String? auditId,
  }) async {
    var qs = 'limit=$limit&offset=$offset';
    if (auditId != null && auditId.trim().isNotEmpty) {
      qs += '&audit_id=${Uri.encodeComponent(auditId.trim())}';
    }
    return getJson('/api/features/preview?$qs');
  }


  Future<Map<String, dynamic>> detectionResults({
    int limit = 200,
    int offset = 0,
    bool onlyAnomalies = true,
    double minRisk = 0,
    String q = '',
    String sort = 'risk_desc',
    String? auditId,
  }) async {
    final parts = <String>[
      'limit=$limit',
      'offset=$offset',
      'only_anomalies=${onlyAnomalies ? 1 : 0}',
      'min_risk=${minRisk.toStringAsFixed(2)}',
      'sort=${Uri.encodeComponent(sort)}',
      'q=${Uri.encodeComponent(q)}',
    ];

    if (auditId != null && auditId.trim().isNotEmpty) {
      parts.add('audit_id=${Uri.encodeComponent(auditId.trim())}');
    }

    final qs = parts.join('&');
    final r = await c.get(Uri.parse('$b/api/detection/results?$qs'));
    if (r.statusCode ~/ 100 == 2) return _decode(r);
    throw Exception('${r.statusCode} ${r.body}');
  }

  // Report Generation
  Future<Map<String, dynamic>> reportSummary() =>
      getJson('/api/reports/summary');

  Future<Map<String, dynamic>> reportPreview({String reportType = 'executive'}) =>
      getJson('/api/reports/preview?report_type=$reportType');

  Future<Uint8List> reportGeneratePdf({String reportType = 'executive'}) async {
    final r = await c.post(Uri.parse('$b/api/reports/generate?report_type=$reportType'));
    if (r.statusCode ~/ 100 == 2) return r.bodyBytes;
    throw Exception('${r.statusCode} ${r.body}');
  }

  // Upload a JSON file and get a preview (uses /api/reports/preview-upload)
  Future<Map<String, dynamic>> reportPreviewUpload({
    required Uint8List bytes,
    required String filename,
  }) async {
    final url = Uri.parse('$b/api/reports/preview-upload');
    final req = http.MultipartRequest('POST', url);
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode ~/ 100 == 2) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return {'data': res.body};
      }
    }
    throw Exception('${res.statusCode} ${res.body}');
  }

  // Upload a JSON file and get generated PDF bytes (uses /api/reports/generate-upload)
  Future<Uint8List> reportGenerateUpload({
    required Uint8List bytes,
    required String filename,
    String language = 'English',
    String color = '#003366',
  }) async {
    final url = Uri.parse('$b/api/reports/generate-upload');
    final req = http.MultipartRequest('POST', url);
    req.fields['language'] = language;
    req.fields['color'] = color;
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode ~/ 100 == 2) return res.bodyBytes;
    throw Exception('${res.statusCode} ${res.body}');
  }

  Future<Map<String, dynamic>> reportHealth() =>
      getJson('/api/reports/health');
}
