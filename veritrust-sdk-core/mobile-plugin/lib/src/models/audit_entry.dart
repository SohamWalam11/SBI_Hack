/// VeriTrust AI — Audit Entry Model
///
/// Client-side representation of an audit trail record.

class AuditEntry {
  final String auditId;
  final DateTime timestamp;
  final String sessionId;
  final String query;
  final String verifiedResponse;
  final bool verificationPassed;
  final List<String> verificationFlags;
  final double confidence;

  const AuditEntry({
    required this.auditId,
    required this.timestamp,
    required this.sessionId,
    required this.query,
    required this.verifiedResponse,
    required this.verificationPassed,
    this.verificationFlags = const [],
    this.confidence = 0.0,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        auditId: json['audit_id'] ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        sessionId: json['session_id'] ?? '',
        query: json['query'] ?? '',
        verifiedResponse: json['verified_response'] ?? '',
        verificationPassed: json['verification_passed'] ?? false,
        verificationFlags:
            List<String>.from(json['verification_flags'] ?? []),
        confidence: (json['confidence'] ?? 0.0).toDouble(),
      );
}
