class ApiEndpoints {
  // Main Production Server
  static const String baseUrl = "https://fe-sawany.vercel.app";

  // Auth
  static const String login = "$baseUrl/api/rider/auth/login";
  static const String logout = "$baseUrl/api/rider/auth/logout";

  // Orders
  static const String orders = "$baseUrl/api/rider/orders";
  static const String updatePricing = "$baseUrl/api/rider/orders/update-pricing";
  static const String settlement = "$baseUrl/api/rider/settlement";

  // Fleet Operations & Live GPS Tracking
  static const String fleet = "$baseUrl/api/rider/fleet";
  static const String location = "$baseUrl/api/rider/location";
  static const String telemetry = "$baseUrl/api/riders/telemetry";
}
