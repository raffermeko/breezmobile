import 'package:breez/theme_data.dart' as theme;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:breez_translations/breez_translations_locales.dart';

const double _kBarSize = 45.0;

class KeyboardDoneAction {
  final List<FocusNode> focusNodes;
  OverlayEntry _overlayEntry;

  KeyboardDoneAction(this.focusNodes) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      focusNodes.forEach((f) => f.addListener(_onFocus));
    }
  }

  void dispose() {
    focusNodes.forEach((f) => f.removeListener(_onFocus));
    _overlayEntry?.remove();
  }

  void _onFocus() {
    bool hasFocus = focusNodes.any((f) => f.hasFocus);
    if (hasFocus && _overlayEntry == null) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    OverlayState os = Overlay.of(focusNodes[0].context);
    _overlayEntry = OverlayEntry(builder: (context) {
      final texts = context.texts();
      final queryData = MediaQuery.of(context);
      // Update and build footer, if any
      return Positioned(
        bottom: queryData.viewInsets.bottom,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.grey[200],
          child: Container(
            height: _kBarSize,
            width: queryData.size.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      texts.keyboard_done_action,
                      style: TextStyle(
                        color: theme.BreezColors.blue[500],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
    os.insert(_overlayEntry);
  }

  void _hideOverlay() {
    _overlayEntry.remove();
    _overlayEntry = null;
  }
}
