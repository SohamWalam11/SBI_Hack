/// VeriTrust AI — Query Request Model
///
/// Represents an outbound query from the mobile client to Core B.

class QueryRequest {
  /// Tokenized session identifier (no PII)
  final String sessionId;

  /// User query text
  final String query;

  /// ISO 639-1 language code for response
  final String language;

  /// Optional contextual metadata
  final Map<String, dynamic> context;

  const QueryRequest({
    required this.sessionId,
    required this.query,
    this.language = 'en',
    this.context = const {},
  });

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'query': query,
        'language': language,
        'context': context,
      };
}
