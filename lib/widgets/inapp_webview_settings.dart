import 'package:flutter_inappwebview/flutter_inappwebview.dart';

InAppWebViewSettings buildAppWebViewSettings({
  bool transparentBackground = false,
  bool allowFileUrlAccess = false,
  bool allowUniversalFileUrlAccess = false,
}) {
  return InAppWebViewSettings(
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    mediaPlaybackRequiresUserGesture: false,
    safeBrowsingEnabled: true,
    thirdPartyCookiesEnabled: true,
    useHybridComposition: true,
    supportMultipleWindows: true,
    transparentBackground: transparentBackground,
    allowFileAccessFromFileURLs: allowFileUrlAccess,
    allowUniversalAccessFromFileURLs: allowUniversalFileUrlAccess,
  );
}
