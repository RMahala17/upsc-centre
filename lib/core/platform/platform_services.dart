// Browser-only abilities (file download / upload, persistent storage, install
// prompt, address-bar colour). Other platforms get safe no-op versions, so
// callers can always call these and check the result.
//
// The web version talks to small helpers in `web/index.html` (`window.upscApp`).
export 'platform_stub.dart' if (dart.library.js_interop) 'platform_web.dart';
