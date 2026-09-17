class Ride {
  final String id;
  final String rideCreatorUid;
  final String rideCreatorName;
  final String pickup;
  final String destination;
  final String date;
  final String time;
  final String vehicleType;
  final int totalSeats;
  int availableSeats;
  final double estimatedCost;

  // Ride status can be Active, Waiting, Started, or Cancelled.
  String status;

  Ride({
    required this.id,
    required this.rideCreatorUid,
    required this.rideCreatorName,
    required this.pickup,
    required this.destination,
    required this.date,
    required this.time,
    required this.vehicleType,
    required this.totalSeats,
    required this.availableSeats,
    required this.estimatedCost,
    this.status = 'Active',
  });

  double get costPerPerson {
    if (totalSeats <= 0) {
      return estimatedCost;
    }

    return estimatedCost / totalSeats;
  }

  // Convert a Ride object into Firestore data.
  Map<String, dynamic> toMap() {
    return {
      'rideCreatorUid': rideCreatorUid,
      'rideCreatorName': rideCreatorName,
      'pickup': pickup,
      'destination': destination,
      'date': date,
      'time': time,
      'vehicleType': vehicleType,
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'estimatedCost': estimatedCost,
      'status': status,
    };
  }

  // Create a Ride object from Firestore data.
  factory Ride.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    return Ride(
      id: id,
      rideCreatorUid: map['rideCreatorUid'] ?? '',
      rideCreatorName: map['rideCreatorName'] ?? '',
      pickup: map['pickup'] ?? '',
      destination: map['destination'] ?? '',
      date: map['date'] ?? '',
      time: map['time'] ?? '',
      vehicleType: map['vehicleType'] ?? '',
      totalSeats: (map['totalSeats'] ?? 0) as int,
      availableSeats: (map['availableSeats'] ?? 0) as int,
      estimatedCost: (map['estimatedCost'] ?? 0).toDouble(),
      status: map['status'] ?? 'Active',
    );
  }
}