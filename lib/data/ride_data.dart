import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ride_model.dart';

class RideData {
  // Local list is kept temporarily so existing screens can continue
  // working while Firebase becomes the main shared data source.
  static final List<Ride> rides = [];

  static final CollectionReference<Map<String, dynamic>> _ridesCollection =
      FirebaseFirestore.instance.collection('rides');

  // Save a ride to Firebase Firestore.
  static Future<void> addRide(Ride ride) async {
    await _ridesCollection.doc(ride.id).set(ride.toMap());

    // Keep the local list updated too.
    rides.removeWhere((existingRide) => existingRide.id == ride.id);
    rides.add(ride);
  }

  // Get all rides from Firebase Firestore.
  static Future<List<Ride>> getRides() async {
    final snapshot = await _ridesCollection.get();

    final firebaseRides = snapshot.docs.map((doc) {
      return Ride.fromMap(doc.id, doc.data());
    }).toList();

    // Keep the local list synchronized.
    rides
      ..clear()
      ..addAll(firebaseRides);

    return firebaseRides;
  }

  // Update an existing ride in Firebase.
  static Future<void> updateRide(Ride ride) async {
    await _ridesCollection.doc(ride.id).update(ride.toMap());

    final index = rides.indexWhere(
      (existingRide) => existingRide.id == ride.id,
    );

    if (index != -1) {
      rides[index] = ride;
    }
  }

  // Reserve one seat using a Firestore transaction.
  //
  // This makes the seat update safer when multiple students
  // try to join the same ride at nearly the same time.
  static Future<Ride> reserveSeat(String rideId) async {
    final Ride updatedRide = await FirebaseFirestore.instance
        .runTransaction<Ride>((transaction) async {
          final DocumentReference<Map<String, dynamic>> rideReference =
              _ridesCollection.doc(rideId);

          final DocumentSnapshot<Map<String, dynamic>> snapshot =
              await transaction.get(rideReference);

          if (!snapshot.exists) {
            throw Exception('Ride not found.');
          }

          final Map<String, dynamic> data = snapshot.data()!;

          final Ride currentRide = Ride.fromMap(
            snapshot.id,
            data,
          );

          // Do not allow a seat to be reserved if the ride
          // is cancelled or already started.
          if (currentRide.status == 'Cancelled') {
            throw Exception('This ride has been cancelled.');
          }

          if (currentRide.status == 'Started') {
            throw Exception('This ride has already started.');
          }

          // Do not allow a seat after the connection period.
          final DateTime? rideDateTime = _getRideDateTime(currentRide);

          if (rideDateTime != null) {
            final DateTime now = DateTime.now();

            if (!now.isBefore(rideDateTime)) {
              final DateTime waitingEnd = rideDateTime.add(
                const Duration(minutes: 10),
              );

              if (!now.isBefore(waitingEnd)) {
                throw Exception(
                  'The 10-minute connection period has ended.',
                );
              }
            }
          }

          // Check the latest seat count directly from Firebase.
          if (currentRide.availableSeats <= 0) {
            throw Exception('Sorry, no seats are available for this ride.');
          }

          // Decrease the seat count.
          final int newAvailableSeats =
              currentRide.availableSeats - 1;

          transaction.update(rideReference, {
            'availableSeats': newAvailableSeats,
          });

          // Create the updated Ride object.
          currentRide.availableSeats = newAvailableSeats;

          return currentRide;
        });

    // Keep the local copy synchronized with Firebase.
    final index = rides.indexWhere(
      (existingRide) => existingRide.id == updatedRide.id,
    );

    if (index != -1) {
      rides[index] = updatedRide;
    } else {
      rides.add(updatedRide);
    }

    return updatedRide;
  }

  // Convert the stored date and time into DateTime.
  static DateTime? _getRideDateTime(Ride ride) {
    try {
      final List<String> dateParts = ride.date.split('/');

      if (dateParts.length != 3) {
        return null;
      }

      final int day = int.parse(dateParts[0]);
      final int month = int.parse(dateParts[1]);
      final int year = int.parse(dateParts[2]);

      final List<String> timeParts = ride.time.split(' ');

      final List<String> clockParts = timeParts[0].split(':');

      int hour = int.parse(clockParts[0]);
      final int minute = int.parse(clockParts[1]);

      if (timeParts.length > 1) {
        final String period = timeParts[1].toUpperCase();

        if (period == 'PM' && hour != 12) {
          hour += 12;
        }

        if (period == 'AM' && hour == 12) {
          hour = 0;
        }
      }

      return DateTime(
        year,
        month,
        day,
        hour,
        minute,
      );
    } catch (e) {
      return null;
    }
  }
}