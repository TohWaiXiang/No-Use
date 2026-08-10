// Set in env.json (loaded via --dart-define-from-file, already wired in
// .vscode/launch.json). Update that one line if the Render backend URL
// ever changes instead of editing source and rebuilding.
const String backendBaseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://no-use-mdr0.onrender.com',
);
