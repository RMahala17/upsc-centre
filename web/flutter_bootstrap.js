{{flutter_js}}
{{flutter_build_config}}

// No `serviceWorkerSettings` here on purpose: Flutter's own service worker is
// not used. Offline support comes from upsc_sw.js, registered in index.html.
_flutter.loader.load();
