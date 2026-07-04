/// VeriTrust AI — SSE Stream Handler
///
/// Intercepted token stream observer for real-time response rendering.
/// Connects to the `/api/v1/query/stream` SSE endpoint, buffers tokens,
/// and emits verification status once the stream completes.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'redactor.dart';

/// Represents a single SSE event from the stream.
class StreamEvent {
  final String type; // 'token', 'verification', 'done', 'error'
  final String? content;
  final bool? done;
  final bool? verificationPassed;
  final List<String>? flags;
  final double? confidence;
  final String? errorMessage;

  const StreamEvent({
    required this.type,
    this.content,
    this.done,
    this.verificationPassed,
    this.flags,
    this.confidence,
    this.errorMessage,
  });

  factory StreamEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'unknown';
    return StreamEvent(
      type: type,
      content: json['content'] as String?,
      done: json['done'] as bool?,
      verificationPassed: json['passed'] as bool?,
      flags: (json['flags'] as List<dynamic>?)?.cast<String>(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      errorMessage: json['message'] as String?,
    );
  }
}

/// Manages SSE streaming connections to Core B.
class VeriTrustStreamHandler {
  final VeriTrustConfig config;
  final VeriTrustRedactor _redactor;

  StreamController<StreamEvent>? _controller;
  http.Client? _httpClient;

  VeriTrustStreamHandler({required this.config})
      : _redactor = VeriTrustRedactor();

  /// Start a streaming query. Returns a stream of [StreamEvent]s.
  ///
  /// Events are emitted in this order:
  /// 1. Multiple 'token' events with incremental content
  /// 2. One 'verification' event with pass/fail status
  /// 3. One 'done' event
  Stream<StreamEvent> streamQuery(
    String queryText, {
    Map<String, dynamic>? context,
    String? language,
  }) {
    _controller = StreamController<StreamEvent>();

    // Fire-and-forget the async connection
    _connectAndStream(queryText, context: context, language: language);

    return _controller!.stream;
  }

  Future<void> _connectAndStream(
    String queryText, {
    Map<String, dynamic>? context,
    String? language,
  }) async {
    _httpClient = http.Client();

    try {
      // PII redaction
      final redactedQuery = _redactor.redactAll(queryText);

      final requestBody = jsonEncode({
        'session_id': config.sessionId,
        'query': redactedQuery,
        'language': language ?? config.language,
        'context': context ?? {},
      });

      final request = http.Request('POST', Uri.parse(config.streamUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        ...config.headers,
      });
      request.body = requestBody;

      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        _controller?.add(StreamEvent(
          type: 'error',
          errorMessage: 'Stream connection failed: ${response.statusCode}',
        ));
        _controller?.close();
        return;
      }

      // Parse SSE stream
      final lineBuffer = StringBuffer();

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        lineBuffer.write(chunk);
        final lines = lineBuffer.toString().split('\n');

        // Keep the last potentially incomplete line in the buffer
        lineBuffer.clear();
        if (!chunk.endsWith('\n')) {
          lineBuffer.write(lines.removeLast());
        }

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('data: ')) {
            final jsonStr = trimmed.substring(6);
            try {
              final json = jsonDecode(jsonStr) as Map<String, dynamic>;
              final event = StreamEvent.fromJson(json);
              _controller?.add(event);

              if (event.type == 'done' || event.type == 'error') {
                await _cleanup();
                return;
              }
            } catch (e) {
              // Skip malformed SSE events
            }
          }
        }
      }

      await _cleanup();
    } catch (e) {
      _controller?.add(StreamEvent(
        type: 'error',
        errorMessage: 'Stream error: $e',
      ));
      await _cleanup();
    }
  }

  Future<void> _cleanup() async {
    _httpClient?.close();
    _httpClient = null;
    await _controller?.close();
    _controller = null;
  }

  /// Cancel the active stream.
  void cancel() {
    _httpClient?.close();
    _httpClient = null;
    _controller?.close();
    _controller = null;
  }

  /// Whether a stream is currently active.
  bool get isStreaming => _controller != null && !_controller!.isClosed;
}
