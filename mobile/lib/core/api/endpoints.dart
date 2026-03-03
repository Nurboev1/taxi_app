class Endpoints {
  static const baseUrl = 'http://192.168.100.8:8000';

  static const requestOtp = '/auth/request-otp';
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
  static String wsChat(int id, String token) =>
      'ws://192.168.100.8:8000/ws/chats/$id?token=$token';

  static const myNotifications = '/notifications/my';
  static String markNotificationRead(int id) => '/notifications/$id/read';
  static const readAllNotifications = '/notifications/read-all';
}
