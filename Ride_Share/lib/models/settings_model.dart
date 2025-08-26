class Settings {
  final String id;
  final double commissionRate;
  final int bookingTimeLimitHours;
  final int cancellationTimeLimitHoursPassenger;
  final int cancellationTimeLimitHoursDriver;

  Settings({
    required this.id,
    required this.commissionRate,
    required this.bookingTimeLimitHours,
    required this.cancellationTimeLimitHoursPassenger,
    required this.cancellationTimeLimitHoursDriver,
  });

  factory Settings.fromMap(Map<String, dynamic> map) {
    return Settings(
      id: map['_id'] ?? map['id'] ?? '', // Handle both _id from DB and id from other sources
      commissionRate: (map['commissionRate'] as num? ?? 0.15).toDouble(),
      bookingTimeLimitHours: (map['bookingTimeLimitHours'] as num? ?? 1).toInt(), // Default to 1 hour
      cancellationTimeLimitHoursPassenger: (map['cancellationTimeLimitHoursPassenger'] as num? ?? 2).toInt(), // Default to 2 hours
      cancellationTimeLimitHoursDriver: (map['cancellationTimeLimitHoursDriver'] as num? ?? 4).toInt(), // Default to 4 hours
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commissionRate': commissionRate,
      'bookingTimeLimitHours': bookingTimeLimitHours,
      'cancellationTimeLimitHoursPassenger': cancellationTimeLimitHoursPassenger,
      'cancellationTimeLimitHoursDriver': cancellationTimeLimitHoursDriver,
    };
  }
}
