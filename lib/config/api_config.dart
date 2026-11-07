/// Base URL for all SnapOdr API requests (login, orders, status updates).
///
/// Defaults to local development. Set an explicit endpoint when building:
/// `flutter run --dart-define=API_BASE_URL=http://localhost:3000`
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);
