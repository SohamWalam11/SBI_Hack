# VeriTrust AI — Flutter Mobile Plugin (Core A)

> Pluggable overlay widget for verified AI-powered banking assistance in YONO 2.0

## Integration

Add to your `pubspec.yaml`:

```yaml
dependencies:
  veritrust_sdk:
    path: ../mobile-plugin  # or published package
```

## Usage

```dart
import 'package:veritrust_sdk/veritrust_sdk.dart';

// Configure
final config = VeriTrustConfig(
  baseUrl: 'https://your-backend.sbi.co.in',
  sessionId: userSession.tokenizedId,
  language: 'en',
);

// Add overlay to your widget tree
Stack(
  children: [
    YourExistingScreen(),
    Positioned(
      left: 0, right: 0, bottom: 0,
      height: MediaQuery.of(context).size.height * 0.7,
      child: VeriTrustOverlay(
        config: config,
        onClose: () => setState(() => showOverlay = false),
      ),
    ),
  ],
);
```

## Features

- 🛡️ **Verified Responses** — Every AI response shows a verification badge
- 📄 **Citation Chips** — Source compliance documents cited inline
- 🔒 **PII Redaction** — Aadhaar, PAN, card numbers stripped before transmission
- 🌊 **SSE Streaming** — Real-time token-by-token response rendering
- 🎨 **Premium UI** — SBI-branded dark-mode with glassmorphism
- 📊 **Audit Trail** — Full transaction history accessible per session

## Architecture

```
User Input → PII Redaction → Core B API → Verified Response → UI Render
                                              ↓
                                    Verification Badge
                                    Citation Chips
                                    Audit Logging
```
