/// VeriTrust AI — Query Response Model
///
/// Represents a verified response from Core B.

class Citation {
  final String sourceDocument;
  final String section;
  final int? page;
  final double relevanceScore;

  const Citation({
    required this.sourceDocument,
    this.section = '',
    this.page,
    this.relevanceScore = 0.0,
  });

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
        sourceDocument: json['source_document'] ?? '',
        section: json['section'] ?? '',
        page: json['page'],
        relevanceScore: (json['relevance_score'] ?? 0.0).toDouble(),
      );
}

class VerificationResult {
  final bool passed;
  final List<String> flags;
  final String? correctedValue;
  final List<String> rulesApplied;

  const VerificationResult({
    required this.passed,
    this.flags = const [],
    this.correctedValue,
    this.rulesApplied = const [],
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) =>
      VerificationResult(
        passed: json['passed'] ?? false,
        flags: List<String>.from(json['flags'] ?? []),
        correctedValue: json['corrected_value'],
        rulesApplied: List<String>.from(json['rules_applied'] ?? []),
      );
}

class ActionIntent {
  final String actionType;
  final Map<String, dynamic> parameters;
  final String riskTier;
  final String actionToken;

  const ActionIntent({
    required this.actionType,
    required this.parameters,
    required this.riskTier,
    required this.actionToken,
  });

  factory ActionIntent.fromJson(Map<String, dynamic> json) => ActionIntent(
        actionType: json['action_type'] ?? '',
        parameters: json['parameters'] ?? {},
        riskTier: json['risk_tier'] ?? 'LOW',
        actionToken: json['action_token'] ?? '',
      );
}

class QueryResponse {
  final String sessionId;
  final String answer;
  final bool verified;
  final double confidence;
  final List<Citation> citations;
  final VerificationResult verification;
  final ActionIntent? actionIntent;
  final String auditId;

  const QueryResponse({
    required this.sessionId,
    required this.answer,
    required this.verified,
    required this.confidence,
    required this.citations,
    required this.verification,
    this.actionIntent,
    required this.auditId,
  });

  factory QueryResponse.fromJson(Map<String, dynamic> json) => QueryResponse(
        sessionId: json['session_id'] ?? '',
        answer: json['answer'] ?? '',
        verified: json['verified'] ?? false,
        confidence: (json['confidence'] ?? 0.0).toDouble(),
        citations: (json['citations'] as List<dynamic>?)
                ?.map((c) => Citation.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        verification: VerificationResult.fromJson(
          json['verification'] ?? {'passed': false},
        ),
        actionIntent: json['action_intent'] != null
            ? ActionIntent.fromJson(json['action_intent'])
            : null,
        auditId: json['audit_id'] ?? '',
      );
}
