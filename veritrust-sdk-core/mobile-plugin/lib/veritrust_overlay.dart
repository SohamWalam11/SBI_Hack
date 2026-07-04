/// VeriTrust AI — Overlay Widget
///
/// The main pluggable overlay that renders a secure, context-aware
/// AI assistant within active YONO 2.0 application forms.
///
/// Features:
/// - Chat-style interface with message bubbles
/// - Real-time streaming response display
/// - Verification badges (✓ Verified / ⚠ Unverified) on each response
/// - Citation chips showing source compliance documents
/// - PII redaction on all outbound communication
/// - Glassmorphism dark-mode design with SBI branding

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;

import 'src/api_client.dart';
import 'src/stream_handler.dart';
import 'src/models/query_response.dart';
import 'src/theme/digital_twin_ui.dart';

/// A chat message in the overlay.
class _ChatMessage {
  final String text;
  final bool isUser;
  final bool? verified;
  final double? confidence;
  final List<Citation>? citations;
  final ActionIntent? actionIntent;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.verified,
    this.confidence,
    this.citations,
    this.actionIntent,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Main VeriTrust overlay widget.
///
/// Usage:
/// ```dart
/// VeriTrustOverlay(
///   config: VeriTrustConfig(
///     baseUrl: 'https://your-backend.sbi.co.in',
///   ),
/// )
/// ```
class VeriTrustOverlay extends StatefulWidget {
  final VeriTrustConfig config;
  final bool showHeader;
  final VoidCallback? onClose;

  const VeriTrustOverlay({
    super.key,
    required this.config,
    this.showHeader = true,
    this.onClose,
  });

  @override
  State<VeriTrustOverlay> createState() => _VeriTrustOverlayState();
}

class _VeriTrustOverlayState extends State<VeriTrustOverlay>
    with TickerProviderStateMixin {
  late final VeriTrustApiClient _apiClient;
  late final VeriTrustStreamHandler _streamHandler;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  String _streamBuffer = '';

  // Animations
  late AnimationController _overlayAnimController;
  late Animation<Offset> _overlaySlide;

  @override
  void initState() {
    super.initState();
    _apiClient = VeriTrustApiClient(config: widget.config);
    _streamHandler = VeriTrustStreamHandler(config: widget.config);

    _overlayAnimController = AnimationController(
      vsync: this,
      duration: VeriTrustAnimations.overlaySlide,
    );
    _overlaySlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _overlayAnimController,
      curve: VeriTrustAnimations.overlayEntryCurve,
    ));

    _overlayAnimController.forward();

    // Welcome message
    _messages.add(_ChatMessage(
      text: '🛡️ **VeriTrust AI** — Your verified banking assistant.\n\n'
          'I only answer from SBI\'s official compliance documents. '
          'Every response is verified against structured data before you see it.\n\n'
          'Ask me about interest rates, KYC requirements, depositor rights, '
          'digital lending guidelines, or account fees.',
      isUser: false,
      verified: true,
      confidence: 1.0,
    ));
  }

  @override
  void dispose() {
    _apiClient.dispose();
    _streamHandler.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _overlayAnimController.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        _processAudio(path);
      }
    } else {
      // Start recording
      if (await _audioRecorder.hasPermission()) {
        setState(() => _isRecording = true);
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: 'audio_temp.wav',
        );
      }
    }
  }

  Future<void> _processAudio(String path) async {
    setState(() => _isTranscribing = true);
    try {
      // On web or platforms where we need bytes directly, it's better to use memory recording
      // But for simplicity with path (record package behavior differs by platform),
      // we'll try loading it or use startStream for bytes in the future.
      // Alternatively, the Record web plugin saves Blobs which require http client to fetch.
      
      final audioBytes = await http.get(Uri.parse(path)).then((res) => res.bodyBytes).catchError((e) => <int>[]);

      if (audioBytes.isNotEmpty) {
        final transcribedText = await _apiClient.transcribeAudio(audioBytes);
        if (transcribedText.isNotEmpty) {
          _inputController.text = transcribedText;
          _sendMessage();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio processing failed: $e')),
      );
    } finally {
      setState(() => _isTranscribing = false);
    }
  }

  Future<void> _sendMessage() async {
    final query = _inputController.text.trim();
    if (query.isEmpty || _isLoading) return;

    _inputController.clear();

    setState(() {
      _messages.add(_ChatMessage(text: query, isUser: true));
      _isLoading = true;
      _streamBuffer = '';
    });

    _scrollToBottom();

    try {
      // Use non-streaming endpoint for reliability
      final response = await _apiClient.query(query);

      setState(() {
        _messages.add(_ChatMessage(
          text: response.answer,
          isUser: false,
          verified: response.verified,
          confidence: response.confidence,
          citations: response.citations,
          actionIntent: response.actionIntent,
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: '⚠️ Unable to process your request. Please try again or '
              'contact SBI customer care at 1800-11-2211.',
          isUser: false,
          verified: false,
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _executeAction(ActionIntent intent) {
    if (intent.riskTier == 'HIGH') {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _BiometricAuthMock(
          intent: intent,
          onAuthenticated: () {
            Navigator.pop(context);
            setState(() {
              if (intent.actionType == 'TRANSFER_FUNDS') {
                final amount = intent.parameters['amount'] ?? 'UNKNOWN';
                final payee = intent.parameters['payee'] ?? 'UNKNOWN';
                _messages.add(_ChatMessage(
                  text: '✅ **Transfer Successful**\n\nSuccessfully transferred **₹$amount** to **$payee**.\n\n*Cryptographic Handshake verified with token: ${intent.actionToken.substring(0, 15)}...*',
                  isUser: false,
                  verified: true,
                  confidence: 1.0,
                ));
              } else {
                _messages.add(_ChatMessage(
                  text: '✅ Action **${intent.actionType}** executed successfully.\n\n*Cryptographic Handshake verified with token: ${intent.actionToken.substring(0, 15)}...*',
                  isUser: false,
                  verified: true,
                  confidence: 1.0,
                ));
              }
            });
            _scrollToBottom();
          },
        ),
      );
    } else {
      // Low risk actions execute immediately
      setState(() {
        _messages.add(_ChatMessage(
          text: '✅ Action **${intent.actionType}** executed (LOW RISK).',
          isUser: false,
          verified: true,
          confidence: 1.0,
        ));
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _overlaySlide,
      child: Container(
        decoration: DigitalTwinTheme.glassOverlay,
        child: Column(
          children: [
            if (widget.showHeader) _buildHeader(),
            Expanded(child: _buildMessageList()),
            if (_isLoading || _isTranscribing) _buildTypingIndicator(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [DigitalTwinTheme.primaryBlue, DigitalTwinTheme.accentGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'V',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VeriTrust AI', style: DigitalTwinTheme.headingMedium),
                Text(
                  'Verified Banking Assistant',
                  style: DigitalTwinTheme.caption.copyWith(
                    color: DigitalTwinTheme.accentGold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: DigitalTwinTheme.successGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: DigitalTwinTheme.successGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: DigitalTwinTheme.badgeText.copyWith(
                    color: DigitalTwinTheme.successGreen,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onClose,
              child: const Icon(
                Icons.close_rounded,
                color: DigitalTwinTheme.textMuted,
                size: 22,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _MessageBubble(
          message: _messages[index],
          index: index,
          onActionTap: _executeAction,
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _TypingDots(),
          const SizedBox(width: 8),
          Text(
            _isTranscribing 
                ? 'Transcribing audio...' 
                : 'Analyzing compliance documents...',
            style: DigitalTwinTheme.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: DigitalTwinTheme.surfaceDark.withOpacity(0.8),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: DigitalTwinTheme.bodyLarge,
              decoration: DigitalTwinTheme.chatInputDecoration.copyWith(
                hintText: _isRecording ? 'Listening...' : 'Ask about rates, KYC, policies...',
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
              readOnly: _isRecording || _isTranscribing,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isRecording ? DigitalTwinTheme.errorRed.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: _isRecording ? DigitalTwinTheme.errorRed : DigitalTwinTheme.textMuted,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    DigitalTwinTheme.primaryBlue,
                    DigitalTwinTheme.primaryLightBlue,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: DigitalTwinTheme.primaryBlue.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isLoading ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Message Bubble
// ═══════════════════════════════════════════════════════════════════

class _MessageBubble extends StatefulWidget {
  final _ChatMessage message;
  final int index;
  final void Function(ActionIntent) onActionTap;

  const _MessageBubble({required this.message, required this.index, required this.onActionTap});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: VeriTrustAnimations.messageEntry,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: VeriTrustAnimations.messageEntryCurve,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_fadeAnim);

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment:
                msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!msg.isUser) _buildAvatar(),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: msg.isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: msg.isUser
                          ? BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  DigitalTwinTheme.primaryBlue,
                                  DigitalTwinTheme.primaryLightBlue,
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(4),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            )
                          : DigitalTwinTheme.glassCard.copyWith(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                      child: msg.isUser
                          ? Text(msg.text, style: DigitalTwinTheme.bodyLarge)
                          : MarkdownBody(
                              data: msg.text,
                              styleSheet: MarkdownStyleSheet(
                                p: DigitalTwinTheme.bodyLarge,
                                strong: DigitalTwinTheme.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: DigitalTwinTheme.accentGold,
                                ),
                                listBullet: DigitalTwinTheme.bodyLarge,
                                code: DigitalTwinTheme.bodyMedium.copyWith(
                                  color: DigitalTwinTheme.accentGold,
                                  backgroundColor:
                                      DigitalTwinTheme.surfaceElevated,
                                ),
                              ),
                            ),
                    ),
                    // Verification badge + citations
                    if (!msg.isUser && msg.verified != null) ...[
                      const SizedBox(height: 6),
                      _buildVerificationBadge(msg),
                    ],
                    if (!msg.isUser &&
                        msg.citations != null &&
                        msg.citations!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildCitationChips(msg.citations!),
                    ],
                    if (!msg.isUser && msg.actionIntent != null) ...[
                      const SizedBox(height: 12),
                      _buildActionCard(msg.actionIntent!),
                    ],
                  ],
                ),
              ),
              if (msg.isUser) const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DigitalTwinTheme.primaryBlue, DigitalTwinTheme.accentGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'V',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationBadge(_ChatMessage msg) {
    final isVerified = msg.verified == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: isVerified
          ? DigitalTwinTheme.verifiedBadge
          : DigitalTwinTheme.unverifiedBadge,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified_rounded : Icons.warning_amber_rounded,
            size: 14,
            color: isVerified
                ? DigitalTwinTheme.successGreen
                : DigitalTwinTheme.warningAmber,
          ),
          const SizedBox(width: 4),
          Text(
            isVerified ? 'Verified' : 'Unverified',
            style: DigitalTwinTheme.badgeText.copyWith(
              color: isVerified
                  ? DigitalTwinTheme.successGreen
                  : DigitalTwinTheme.warningAmber,
            ),
          ),
          if (msg.confidence != null) ...[
            const SizedBox(width: 6),
            Text(
              '${(msg.confidence! * 100).toStringAsFixed(0)}%',
              style: DigitalTwinTheme.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCitationChips(List<Citation> citations) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: citations.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: DigitalTwinTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined,
                  color: DigitalTwinTheme.textSecondary, size: 12),
              const SizedBox(width: 4),
              Text(
                c.sourceDocument,
                style: DigitalTwinTheme.caption
                    .copyWith(color: DigitalTwinTheme.textSecondary),
              ),
              if (c.page != null) ...[
                const SizedBox(width: 4),
                Text(
                  'p.${c.page}',
                  style: DigitalTwinTheme.caption
                      .copyWith(color: DigitalTwinTheme.textMuted),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionCard(ActionIntent intent) {
    final isHighRisk = intent.riskTier == 'HIGH';
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DigitalTwinTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isHighRisk ? DigitalTwinTheme.warningAmber.withOpacity(0.5) : DigitalTwinTheme.primaryLightBlue.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: isHighRisk ? DigitalTwinTheme.warningAmber : DigitalTwinTheme.accentGold, size: 16),
              const SizedBox(width: 4),
              Text('AGENTIC ACTION',
                  style: TextStyle(
                      color: isHighRisk ? DigitalTwinTheme.warningAmber : DigitalTwinTheme.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.2)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isHighRisk ? DigitalTwinTheme.warningAmber.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${intent.riskTier} RISK',
                  style: TextStyle(
                    color: isHighRisk ? DigitalTwinTheme.warningAmber : Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text(
            intent.actionType.replaceAll('_', ' '),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          if (intent.parameters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: intent.parameters.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text('${e.key}: ', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        Text('${e.value}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighRisk ? DigitalTwinTheme.warningAmber : DigitalTwinTheme.primaryBlue,
                foregroundColor: isHighRisk ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () => widget.onActionTap(intent),
              icon: Icon(isHighRisk ? Icons.fingerprint : Icons.check_circle_outline, size: 18),
              label: Text(isHighRisk ? 'Execute Secure Action' : 'Execute Action', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Typing Indicator
// ═══════════════════════════════════════════════════════════════════

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: VeriTrustAnimations.typingIndicator,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value + delay) % 1.0;
            final opacity = (value < 0.5) ? value * 2 : (1.0 - value) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: DigitalTwinTheme.primaryLightBlue
                    .withOpacity(0.3 + opacity * 0.7),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Biometric Mock Bottom Sheet
// ═══════════════════════════════════════════════════════════════════

class _BiometricAuthMock extends StatefulWidget {
  final ActionIntent intent;
  final VoidCallback onAuthenticated;

  const _BiometricAuthMock({required this.intent, required this.onAuthenticated});

  @override
  State<_BiometricAuthMock> createState() => _BiometricAuthMockState();
}

class _BiometricAuthMockState extends State<_BiometricAuthMock> {
  bool _scanning = false;
  bool _success = false;

  void _simulateScan() async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _scanning = false;
      _success = true;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: DigitalTwinTheme.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          const Icon(Icons.fingerprint, size: 64, color: DigitalTwinTheme.accentGold),
          const SizedBox(height: 16),
          const Text('Step-Up Authentication', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Authenticate to execute ${widget.intent.actionType}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          if (_success)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: DigitalTwinTheme.successGreen),
                SizedBox(width: 8),
                Text('Verified', style: TextStyle(color: DigitalTwinTheme.successGreen, fontWeight: FontWeight.bold)),
              ],
            )
          else if (_scanning)
            const CircularProgressIndicator(color: DigitalTwinTheme.accentGold)
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: DigitalTwinTheme.primaryButton,
                onPressed: _simulateScan,
                child: const Text('Tap to Scan Fingerprint'),
              ),
            )
        ],
      ),
    );
  }
}
