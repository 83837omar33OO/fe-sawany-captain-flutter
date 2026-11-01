class TimeFormatter {
  /// Returns exact, clean Arabic elapsed time (e.g. "منذ 14 دقيقة", "منذ ساعة و 20 دقيقة", "منذ ساعتين و 5 دقائق")
  static String formatElapsedTime(DateTime? dateTime) {
    if (dateTime == null) return "الآن";
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative || difference.inSeconds < 45) {
      return "الآن";
    }

    final minutes = difference.inMinutes;
    final hours = difference.inHours;

    if (minutes < 60) {
      return "منذ $minutes دقيقة";
    }

    final remainingMinutes = minutes % 60;

    String hourText;
    if (hours == 1) {
      hourText = "ساعة";
    } else if (hours == 2) {
      hourText = "ساعتين";
    } else if (hours >= 3 && hours <= 10) {
      hourText = "$hours ساعات";
    } else {
      hourText = "$hours ساعة";
    }

    if (remainingMinutes == 0) {
      return "منذ $hourText";
    }

    return "منذ $hourText و $remainingMinutes دقيقة";
  }

  /// True if order has been created for thresholdMinutes or longer
  static bool isDelayed(DateTime? dateTime, {int thresholdMinutes = 20}) {
    if (dateTime == null) return false;
    return DateTime.now().difference(dateTime).inMinutes >= thresholdMinutes;
  }

  /// Elapsed minutes integer
  static int elapsedMinutes(DateTime? dateTime) {
    if (dateTime == null) return 0;
    return DateTime.now().difference(dateTime).inMinutes;
  }
}
