import 'package:flutter/material.dart';
import 'package:veritrust_sdk/veritrust_sdk.dart';

/// The formalized entry point for the VeriTrust AI Agent Plugin.
/// 
/// This encapsulates the overlay logic, providing a seamless "drop-in"
/// SDK experience for integrating banking AI into any Flutter app.
class VeriTrustAgentPlugin {
  static VeriTrustConfig? _config;
  static OverlayEntry? _overlayEntry;

  /// Initialize the plugin with the required backend configuration.
  /// This must be called before [show].
  static void initialize(VeriTrustConfig config) {
    _config = config;
  }

  /// Displays the AI Assistant overlay over the current context.
  static void show(BuildContext context) {
    if (_config == null) {
      throw Exception('VeriTrustAgentPlugin has not been initialized. Call initialize() first.');
    }
    
    if (_overlayEntry != null) return; // Already showing

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Darkened background
          Positioned.fill(
            child: GestureDetector(
              onTap: hide,
              child: Container(color: Colors.black54),
            ),
          ),
          // Bottom sheet overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Material(
              type: MaterialType.transparency,
              child: VeriTrustOverlay(
                config: _config!,
                onClose: hide,
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Hides the AI Assistant overlay.
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
