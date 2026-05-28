class AppConfig {
  /// Base API URL for all backend requests.
  /// For Android Emulator use 'http://10.0.2.2:3000'
  /// For Physical Device use your PC's local IP (e.g. 'http://192.168.1.XX:3000')
  /// For Web or Windows Desktop use 'http://localhost:3000'
  static const String baseUrl = 'http://localhost:3000';

  /// Google Sign-In Client ID for OAuth authentication.
  static const String googleClientId = '71666521444-lkcv3d737qu8oqbg17md5cjf99d5o29v.apps.googleusercontent.com';

  /// Facebook App ID required for Instagram Stories sharing.
  /// TODO: Replace with a real Facebook App ID from https://developers.facebook.com/
  ///       Until then, the share falls back to the native OS share sheet automatically.
  ///       Set to empty string '' to always skip to native share.
  static const String facebookAppId = '';
}
