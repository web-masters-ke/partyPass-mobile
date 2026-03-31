class AppConstants {
  AppConstants._();

  static const String apiBaseUrl = 'https://api.partypass.co.ke/api/v1';
  static const String tokenKey = 'partypass_token';
  static const String refreshTokenKey = 'partypass_refresh_token';
  static const String userKey = 'partypass_user';

  static const Duration qrRefreshInterval = Duration(seconds: 30);
  static const Duration cartHoldDuration = Duration(minutes: 15);
}
