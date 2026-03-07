class Endpoints {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://safaruz.duckdns.org',
  );

  static const requestOtp = '/auth/request-otp';
  static const phoneStatus = '/auth/phone-status';
  static const completeOtp = '/auth/complete-otp';
  static const loginPassword = '/auth/login-password';
  static const verifyOtp = '/auth/verify-otp';
  static const setRole = '/role/set';
  static const myProfile = '/auth/profile/me';

  static const createTrip = '/driver/trips';
  static const myTrips = '/driver/trips/my';
  static const openRequests = '/driver/requests/open';
  static String tripPassengers(int tripId) =>
      '/driver/trips/$tripId/passengers';
  static String finishTrip(int tripId) => '/driver/trips/$tripId/finish';
  static String finishPassenger(int tripId, int requestId) =>
      '/driver/trips/$tripId/passengers/$requestId/finish';

  static const createPassengerRequest = '/passenger/requests';

  static String getPassengerRequest(int id) => '/passenger/requests/$id';
  static String getMatches(int requestId) => '/requests/$requestId/matches';
  static String claim(int requestId) => '/requests/$requestId/claim';
  static String claims(int requestId) => '/requests/$requestId/claims';
  static String choose(int requestId) => '/requests/$requestId/choose';

  static const pendingRatings = '/ratings/pending';
  static String rateTrip(int tripId) => '/ratings/trip/$tripId';
  static const myGivenRatings = '/ratings/mine/given';
  static const myReceivedRatings = '/ratings/mine/received';
  static String ratingSummary(int userId) => '/ratings/summary/$userId';

  static String getChat(int id) => '/chats/$id';
  static const myChats = '/chats/my';
  static String sendMessage(int id) => '/chats/$id/messages';
  static String deleteChat(int id) => '/chats/$id';
  static String get _wsBaseUrl {
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '$wsScheme://${uri.host}$port';
  }

  static String wsChat(int id, String token) =>
      '$_wsBaseUrl/ws/chats/$id?token=$token';

  static const myNotifications = '/notifications/my';
  static String markNotificationRead(int id) => '/notifications/$id/read';
  static const readAllNotifications = '/notifications/read-all';
  static const pushToken = '/notifications/push-token';
}
