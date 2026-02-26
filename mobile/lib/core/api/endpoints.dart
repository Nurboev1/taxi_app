class Endpoints {
  static const baseUrl = 'http://192.168.100.8:8000';

  static const requestOtp = '/auth/request-otp';
  static const verifyOtp = '/auth/verify-otp';
  static const setRole = '/role/set';

  static const createTrip = '/driver/trips';
  static const myTrips = '/driver/trips/my';
  static const openRequests = '/driver/requests/open';

  static const createPassengerRequest = '/passenger/requests';

  static String getPassengerRequest(int id) => '/passenger/requests/$id';
  static String getMatches(int requestId) => '/requests/$requestId/matches';
  static String claim(int requestId) => '/requests/$requestId/claim';
  static String claims(int requestId) => '/requests/$requestId/claims';
  static String choose(int requestId) => '/requests/$requestId/choose';

  static String getChat(int id) => '/chats/$id';
  static String sendMessage(int id) => '/chats/$id/messages';
  static String wsChat(int id, String token) =>
      'ws://192.168.100.8:8000/ws/chats/$id?token=$token';
}
