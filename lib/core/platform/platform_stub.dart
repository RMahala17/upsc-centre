/// True when the app can save and open files by itself (the web build).
const bool platformSupportsFiles = false;

/// Starts a file download. Returns false when this platform cannot, so the
/// caller can fall back to copying the text.
Future<bool> downloadTextFile({
  required String filename,
  required String content,
  String mime = 'application/json',
}) async =>
    false;

/// Lets the user pick a text file and returns its contents, or null when they
/// cancel or this platform cannot.
Future<String?> pickTextFile({String accept = '.json'}) async => null;

/// Asks the browser not to clear this app's data. null = not supported.
Future<bool?> requestPersistentStorage() async => null;

/// Whether the browser has promised to keep the data. null = unknown.
Future<bool?> isStoragePersistent() async => null;

bool canInstallApp() => false;

Future<bool> promptInstallApp() async => false;

/// True when running as an installed app (not in a browser tab).
bool isInstalledApp() => false;

/// "#RRGGBB" for the browser's address-bar / status-bar colour.
void setBrowserThemeColor(String hex) {}
