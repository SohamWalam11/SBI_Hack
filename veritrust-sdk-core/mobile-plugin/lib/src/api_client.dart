/// VeriTrust AI — API Client
///
/// HTTP client wrapper for communication with Core B.
/// All outbound payloads pass through PII redaction before transmission.
/// Only tokenized session IDs are sent downstream (DPDP Act compliance).

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'models/query_request.dart';
import 'models/query_response.dart';
import 'redactor.dart';

/// Configuration for the VeriTrust SDK.
class VeriTrustConfig {
  /// Base URL of the Core B backend proxy
  final String baseUrl;

  /// Tokenized session ID (never raw user identifiers)
  final String sessionId;

  /// Default language for responses (ISO 639-1)
  final String language;

  /// Request timeout duration
  final Duration timeout;

  /// Custom HTTP headers (e.g., auth tokens)
  final Map<String, String> headers;

  VeriTrustConfig({
    required this.baseUrl,
    String? sessionId,
    this.language = 'en',
    this.timeout = const Duration(seconds: 30),
    this.headers = const {},
  }) : sessionId = sessionId ?? const Uuid().v4();

  String get queryUrl => '$baseUrl/api/v1/query';
  String get streamUrl => '$baseUrl/api/v1/query/stream';
  String get healthUrl => '$baseUrl/api/v1/health';
  String get ingestUrl => '$baseUrl/api/v1/ingest';
  String get transcribeUrl => '$baseUrl/api/v1/transcribe';
  String rateUrl(String accountType) => '$baseUrl/api/v1/rates/$accountType';
  String get kfsUrl => '$baseUrl/api/v1/kfs/generate';
  String auditUrl(String sessionId) => '$baseUrl/api/v1/audit/$sessionId';
}

/// API client for Core B communication.
class VeriTrustApiClient {
  final VeriTrustConfig config;
  final http.Client _httpClient;
  final VeriTrustRedactor _redactor;

  VeriTrustApiClient({
    required this.config,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
        _redactor = VeriTrustRedactor();

  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...config.headers,
      };

  /// Send a query to Core B and receive a verified response.
  Future<QueryResponse> query(String queryText,
      {Map<String, dynamic>? context}) async {
    // PII redaction before transmission
    final redactedQuery = _redactor.redactAll(queryText);

    final request = QueryRequest(
      sessionId: config.sessionId,
      query: redactedQuery,
      language: config.language,
      context: context ?? {},
    );

    final response = await _httpClient
        .post(
          Uri.parse(config.queryUrl),
          headers: _defaultHeaders,
          body: jsonEncode(request.toJson()),
        )
        .timeout(config.timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return QueryResponse.fromJson(json);
    } else {
      throw VeriTrustApiException(
        statusCode: response.statusCode,
        message: 'Query failed: ${response.body}',
      );
    }
  }

  /// Check backend health status.
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await _httpClient
        .get(
          Uri.parse(config.healthUrl),
          headers: _defaultHeaders,
        )
        .timeout(config.timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw VeriTrustApiException(
        statusCode: response.statusCode,
        message: 'Health check failed',
      );
    }
  }

  /// Lookup interest rates (deterministic, no LLM).
  Future<Map<String, dynamic>> lookupRate(
    String accountType, {
    int? tenureDays,
    String depositorCategory = 'general',
  }) async {
    var url = '${config.rateUrl(accountType)}?depositor_category=$depositorCategory';
    if (tenureDays != null) {
      url += '&tenure_days=$tenureDays';
    }

    final response = await _httpClient
        .get(Uri.parse(url), headers: _defaultHeaders)
        .timeout(config.timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw VeriTrustApiException(
        statusCode: response.statusCode,
        message: 'Rate lookup failed',
      );
    }
  }

  /// Retrieve audit trail for the current session.
  Future<List<Map<String, dynamic>>> getAuditTrail() async {
    final response = await _httpClient
        .get(
          Uri.parse(config.auditUrl(config.sessionId)),
          headers: _defaultHeaders,
        )
        .timeout(config.timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(json['entries'] ?? []);
    } else {
      throw VeriTrustApiException(
        statusCode: response.statusCode,
        message: 'Audit trail retrieval failed',
      );
    }
  }

  /// Transcribe audio using the backend STT engine.
  Future<String> transcribeAudio(List<int> audioBytes,
      {String extension = 'wav'}) async {
    final request = http.MultipartRequest('POST', Uri.parse(config.transcribeUrl))
      ..headers.addAll(config.headers)
      ..files.add(http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: 'audio.$extension',
      ));

    final response = await _httpClient.send(request).timeout(config.timeout);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      return json['text'] as String;
    } else {
      throw VeriTrustApiException(
        statusCode: response.statusCode,
        message: 'Transcription failed: $responseBody',
      );
    }
  }

  /// Clean up resources.
  void dispose() {
    _httpClient.close();
  }
}

/// Custom exception for API errors.
class VeriTrustApiException implements Exception {
  final int statusCode;
  final String message;

  const VeriTrustApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'VeriTrustApiException($statusCode): $message';
}
