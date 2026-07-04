/// VeriTrust AI — Client-Side PII Redactor
///
/// Mirrors the backend `redactor.py` to ensure PII is stripped
/// BEFORE any data leaves the device (DPDP Act compliance).
/// Only tokenized session IDs are transmitted to Core B.

class VeriTrustRedactor {
  // Aadhaar: 12 digits, optionally separated by spaces or hyphens
  static final _aadhaarPattern =
      RegExp(r'\b([2-9]\d{3})[\s\-]?(\d{4})[\s\-]?(\d{4})\b');

  // PAN: 5 uppercase letters + 4 digits + 1 uppercase letter
  static final _panPattern = RegExp(r'\b([A-Z]{5})(\d{4})([A-Z])\b');

  // Card numbers: 13-19 digits, optionally separated
  static final _cardPattern =
      RegExp(r'\b(\d{4})[\s\-]?(\d{4})[\s\-]?(\d{4})[\s\-]?(\d{4})\b');

  // Indian mobile: +91 or 0 prefix + 10 digits
  static final _phonePattern =
      RegExp(r'(?:\+91[\s\-]?|0)?([6-9]\d{4})[\s\-]?(\d{5})\b');

  // Email addresses
  static final _emailPattern =
      RegExp(r'\b([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})\b');

  // Bank Account numbers (SBI uses 11 digits, but covering 11-14 for safety)
  static final _accountPattern = RegExp(r'\b(\d{11,14})\b');

  /// Mask Aadhaar numbers → XXXX-XXXX-1234
  String redactAadhaar(String text) {
    return text.replaceAllMapped(_aadhaarPattern, (match) {
      final lastFour = match.group(3);
      return 'XXXX-XXXX-$lastFour';
    });
  }

  /// Mask PAN → XXXXX1234X
  String redactPan(String text) {
    return text.replaceAllMapped(_panPattern, (match) {
      final digits = match.group(2);
      final last = match.group(3);
      return 'XXXXX$digits$last';
    });
  }

  /// Mask card numbers → XXXX-XXXX-XXXX-1234
  String redactCardNumber(String text) {
    return text.replaceAllMapped(_cardPattern, (match) {
      final lastFour = match.group(4);
      return 'XXXX-XXXX-XXXX-$lastFour';
    });
  }

  /// Mask phone numbers → XXXXX-12345
  String redactPhone(String text) {
    return text.replaceAllMapped(_phonePattern, (match) {
      final lastFive = match.group(2);
      return 'XXXXX-$lastFive';
    });
  }

  /// Mask email → u***@domain.com
  String redactEmail(String text) {
    return text.replaceAllMapped(_emailPattern, (match) {
      final local = match.group(1) ?? '';
      final domain = match.group(2) ?? '';
      final maskedLocal = local.isNotEmpty ? '${local[0]}***' : '***';
      return '$maskedLocal@$domain';
    });
  }

  /// Layer 1 DPDP Filter: Mask Account Numbers → [ACCOUNT_REDACTED]
  String redactAccount(String text) {
    return text.replaceAllMapped(_accountPattern, (match) {
      return '[ACCOUNT_REDACTED]';
    });
  }

  /// Run the full PII redaction pipeline.
  String redactAll(String text) {
    var result = text;
    result = redactAadhaar(result);
    result = redactPan(result);
    result = redactCardNumber(result);
    result = redactAccount(result); // DPDP Filter Layer 1
    result = redactPhone(result);
    result = redactEmail(result);
    return result;
  }

  /// Quick check: does the text contain any detectable PII?
  bool containsPii(String text) {
    return text != redactAll(text);
  }
}
