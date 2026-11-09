import 'dart:js_interop';

// Helpers defined in web/index.html as window.upscApp.
@JS('upscApp.download')
external void _download(JSString name, JSString content, JSString mime);

@JS('upscApp.pickText')
external JSPromise<JSAny?> _pickText(JSString accept);

@JS('upscApp.persist')
external JSPromise<JSAny?> _persist();

@JS('upscApp.persisted')
external JSPromise<JSAny?> _persisted();

@JS('upscApp.canInstall')
external JSBoolean _canInstall();

@JS('upscApp.install')
external JSPromise<JSAny?> _install();

@JS('upscApp.isStandalone')
external JSBoolean _isStandalone();

@JS('upscApp.setThemeColor')
external void _setThemeColor(JSString hex);

const bool platformSupportsFiles = true;

Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mime = 'application/json',
}) async {
  try {
    _download(filename.toJS, content.toJS, mime.toJS);
    return true;
  } catch (_) {
    return false;
  }
}

Future<String?> pickTextFile({String accept = '.json'}) async {
  try {
    final v = await _pickText(accept.toJS).toDart;
    if (v != null && v.isA<JSString>()) return (v as JSString).toDart;
    return null;
  } catch (_) {
    return null;
  }
}

Future<bool?> _asBool(JSPromise<JSAny?> p) async {
  try {
    final v = await p.toDart;
    if (v != null && v.isA<JSBoolean>()) return (v as JSBoolean).toDart;
    return null;
  } catch (_) {
    return null;
  }
}

Future<bool?> requestPersistentStorage() => _asBool(_persist());

Future<bool?> isStoragePersistent() => _asBool(_persisted());

bool canInstallApp() {
  try {
    return _canInstall().toDart;
  } catch (_) {
    return false;
  }
}

Future<bool> promptInstallApp() async => (await _asBool(_install())) ?? false;

bool isInstalledApp() {
  try {
    return _isStandalone().toDart;
  } catch (_) {
    return false;
  }
}

String? _lastThemeColor;

void setBrowserThemeColor(String hex) {
  if (hex == _lastThemeColor) return;
  _lastThemeColor = hex;
  try {
    _setThemeColor(hex.toJS);
  } catch (_) {}
}
