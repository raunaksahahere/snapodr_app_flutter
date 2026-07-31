/// Base URL for all SnapOdr API requests (login, orders, status updates).
///
/// Override for local dev:
/// `flutter run --dart-define=API_BASE_URL=http://localhost:3000`
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://snapodr-website.vercel.app',
);
