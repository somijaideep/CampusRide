import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ride_model.dart';

class RideData {
  // Local list synchronized with Firebase Firestore.
  static final List<Ride> rides = [];

  static final CollectionReference<Map<String, dynamic>>
      _ridesCollection =
      FirebaseFirestore.instance.collection('rides');

  // --------------------------------------------------
  // ADD A RIDE
  // --------------------------------------------------

  static Future<void> addRide(Ride ride) async {
    await _ridesCollection.doc(ride.id).set(ride.toMap());

    rides.removeWhere(
      (existingRide) => existingRide.id == ride.id,
    );

    rides.add(ride);
  }

  // --------------------------------------------------
  // GET ALL RIDES ONCE
  // --------------------------------------------------

  static Future<List<Ride>> getRides() async {
    final snapshot = await _ridesCollection.get();

    final firebaseRides = snapshot.docs.map((doc) {
      return Ride.fromMap(doc.id, doc.data());
    }).toList();

    rides
      ..clear()
      ..addAll(firebaseRides);

    return firebaseRides;
  }

  // --------------------------------------------------
  // LISTEN TO LIVE FIRESTORE UPDATES
  // --------------------------------------------------

  static Stream<List<Ride>> watchRides() {
    return _ridesCollection.snapshots().map((snapshot) {
      final firebaseRides = snapshot.docs.map((doc) {
        return Ride.fromMap(doc.id, doc.data());
      }).toList();

      // Synchronize the local ride list.
      rides
        ..clear()
        ..addAll(firebaseRides);

      return firebaseRides;
    });
  }

  // --------------------------------------------------
  // UPDATE AN EXISTING RIDE
  // --------------------------------------------------

  static Future<void> updateRide(Ride ride) async {
    await _ridesCollection.doc(ride.id).update(ride.toMap());

    final index = rides.indexWhere(
      (existingRide) => existingRide.id == ride.id,
    );

    if (index != -1) {
      rides[index] = ride;
    } else {
      rides.add(ride);
    }
  }

  // --------------------------------------------------
  // RESERVE ONE SEAT SAFELY
  // --------------------------------------------------

  static Future<Ride> reserveSeat(String rideId) async {
    final Ride updatedRide =
        await FirebaseFirestore.instance.runTransaction<Ride>(
      (transaction) async {
        final DocumentReference<Map<String, dynamic>>
            rideReference = _ridesCollection.doc(rideId);

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

        // Do not allow reservations for cancelled rides.
        if (currentRide.status == 'Cancelled') {
          throw Exception('This ride has been cancelled.');
        }

        // Do not allow reservations for started rides.
        if (currentRide.status == 'Started') {
          throw Exception('This ride has already started.');
        }

        // Check the 10-minute connection period.
        final DateTime? rideDateTime =
            _getRideDateTime(currentRide);

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

        // Check available seats using the latest Firestore data.
        if (currentRide.availableSeats <= 0) {
          throw Exception(
            'Sorry, no seats are available for this ride.',
          );
        }

        // Reserve one seat.
        final int newAvailableSeats =
            currentRide.availableSeats - 1;

        transaction.update(rideReference, {
          'availableSeats': newAvailableSeats,
        });

        currentRide.availableSeats = newAvailableSeats;

        return currentRide;
      },
    );

    // Synchronize the local list after the transaction succeeds.
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

  // --------------------------------------------------
  // PARSE RIDE DATE AND TIME
  // --------------------------------------------------

  static DateTime? _getRideDateTime(Ride ride) {
    try {
      // Expected date format: DD/MM/YYYY.
      final List<String> dateParts = ride.date.split('/');

      if (dateParts.length != 3) {
        return null;
      }

      final int day = int.parse(dateParts[0]);
      final int month = int.parse(dateParts[1]);
      final int year = int.parse(dateParts[2]);

      // Supports times such as 10:30 AM or 2:15 PM.
      final List<String> timeParts =
          ride.time.trim().split(RegExp(r'\s+'));

      final List<String> clockParts =
          timeParts[0].split(':');

      if (clockParts.length != 2) {
        return null;
      }

      int hour = int.parse(clockParts[0]);
      final int minute = int.parse(clockParts[1]);

      if (hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59) {
        return null;
      }

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
    } catch (_) {
      return null;
    }
  }
}
