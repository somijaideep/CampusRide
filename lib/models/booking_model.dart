class Booking {
  final String id;
  final String rideId;
  final String studentName;
  final String studentUid;
  String status;

  Booking({
    required this.id,
    required this.rideId,
    required this.studentName,
    required this.studentUid,
    required this.status,
  });
}
