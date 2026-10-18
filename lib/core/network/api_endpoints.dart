class ApiEndpoints {
  static const String baseUrl = "https://tayyar.fe-sawany.online";

  // Auth
  static const String login = "$baseUrl/api/rider/auth/login";
  static const String logout = "$baseUrl/api/rider/auth/logout";

  // Orders
  static const String orders = "$baseUrl/api/rider/orders";
  static const String settlement = "$baseUrl/api/rider/settlement";
}
