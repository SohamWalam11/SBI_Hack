/// VeriTrust AI SDK for Flutter
///
/// A pluggable overlay widget providing verified AI-powered banking
/// assistance within the YONO 2.0 mobile ecosystem.
///
/// ## Quick Start
/// ```dart
/// import 'package:veritrust_sdk/veritrust_sdk.dart';
///
/// VeriTrustOverlay(
///   config: VeriTrustConfig(
///     baseUrl: 'https://your-backend.sbi.co.in',
///     sessionId: userSession.id,
///   ),
/// );
/// ```
library veritrust_sdk;

// Public API exports
export 'veritrust_overlay.dart';
export 'veritrust_agent_plugin.dart';
export 'src/api_client.dart' show VeriTrustConfig;
export 'src/models/query_response.dart';
export 'src/models/query_request.dart';
export 'src/models/audit_entry.dart';
export 'src/theme/digital_twin_ui.dart';
export 'src/redactor.dart' show VeriTrustRedactor;
