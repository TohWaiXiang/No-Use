// Set in env.json (loaded via --dart-define-from-file, already wired in
// .vscode/launch.json). Update that one line when the backend's LAN IP
// changes instead of editing source and rebuilding.
const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://192.168.0.8:8000',
);
