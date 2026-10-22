import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/booking_model.dart';

class BookingData {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static final CollectionReference<Map<String, dynamic>> _bookings =
      _firestore.collection('bookings');

  static final CollectionReference<Map<String, dynamic>> _rides =
      _firestore.collection('rides');

  static List<Booking> bookings = [];

  // =========================================================
  // CREATE BOOKING AND RESERVE A SEAT
  // =========================================================

  static Future<void> createBookingWithSeat({
    required String rideId,
    required String studentName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in before booking a ride.');
    }

    final String studentUid = user.uid;

    if (studentName.trim().isEmpty) {
      throw Exception('Student name cannot be empty.');
    }

    final DocumentReference<Map<String, dynamic>> rideRef =
        _rides.doc(rideId);

    final DocumentReference<Map<String, dynamic>> bookingRef =
        _bookings.doc();

    await _firestore.runTransaction((transaction) async {
      final rideSnapshot = await transaction.get(rideRef);

      if (!rideSnapshot.exists) {
        throw Exception('This ride does not exist.');
      }

      final rideData = rideSnapshot.data()!;

      if (rideData['rideCreatorUid'] == studentUid) {
        throw Exception('You cannot book your own ride.');
      }

      if (rideData['status'] != 'Active') {
        throw Exception('This ride is not available for booking.');
      }

      final int availableSeats =
          (rideData['availableSeats'] as num?)?.toInt() ?? 0;

      if (availableSeats <= 0) {
        throw Exception('No seats are available.');
      }

      // Prevent a second active booking by the same student
      // for the same ride.
      //
      // The query is performed before any transaction writes.
      final existingBookings = await _bookings
          .where('rideId', isEqualTo: rideId)
          .where('studentUid', isEqualTo: studentUid)
          .get();

      final alreadyBooked = existingBookings.docs.any(
        (document) => document.data()['status'] == 'Confirmed',
      );

      if (alreadyBooked) {
        throw Exception('You have already booked this ride.');
      }

      transaction.set(bookingRef, {
        'rideId': rideId,
        'studentUid': studentUid,
        'studentName': studentName.trim(),
        'status': 'Confirmed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(rideRef, {
        'availableSeats': availableSeats - 1,
      });
    });

    await getBookings();
  }

  // =========================================================
  // LOAD CURRENT STUDENT'S BOOKINGS
  // =========================================================

  static Future<void> getBookings() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      bookings = [];
      return;
    }

    final snapshot = await _bookings
        .where('studentUid', isEqualTo: user.uid)
        .get();

    bookings = snapshot.docs.map((document) {
      final data = document.data();

      return Booking(
        id: document.id,
        rideId: data['rideId'] ?? '',
        studentName: data['studentName'] ?? '',
        studentUid: data['studentUid'] ?? '',
        status: data['status'] ?? 'Confirmed',
      );
    }).toList();

    // Newest bookings first, when the creation timestamps exist.
    bookings.sort((a, b) => b.id.compareTo(a.id));
  }

  // =========================================================
  // ADD BOOKING TO LOCAL LIST
  // =========================================================

  static void addBooking(Booking booking) {
    bookings.add(booking);
  }

  // =========================================================
  // UPDATE BOOKING STATUS IN FIRESTORE
  // =========================================================

  static Future<void> updateBooking(Booking booking) async {
    await _bookings.doc(booking.id).update({
      'status': booking.status,
    });

    await getBookings();
  }

  // =========================================================
  // GET CONFIRMED PASSENGERS FOR A RIDE
  // Only the ride creator can retrieve this list.
  // =========================================================

  static Future<List<Map<String, dynamic>>> getConfirmedPassengers(
    String rideId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in to view passengers.');
    }

    final rideSnapshot = await _rides.doc(rideId).get();

    if (!rideSnapshot.exists) {
      throw Exception('Ride not found.');
    }

    final rideData = rideSnapshot.data()!;

    if (rideData['rideCreatorUid'] != user.uid) {
      throw Exception(
        'Only the ride creator can view the passenger list.',
      );
    }

    final snapshot = await _bookings
        .where('rideId', isEqualTo: rideId)
        .get();

    final List<Map<String, dynamic>> passengers = [];

    for (final document in snapshot.docs) {
      final data = document.data();

      if (data['status'] != 'Confirmed') {
        continue;
      }

      final String studentUid = data['studentUid'] ?? '';

      if (studentUid.isEmpty || studentUid == user.uid) {
        continue;
      }

      passengers.add({
        'bookingId': document.id,
        'rideId': data['rideId'] ?? rideId,
        'studentUid': studentUid,
        'studentName': data['studentName'] ?? 'Student',
        'status': data['status'] ?? 'Confirmed',
      });
    }

    return passengers;
  }

  // =========================================================
  // CANCEL BOOKING AND RESTORE THE SEAT
  // Both operations happen in one transaction.
  // =========================================================

  static Future<void> cancelBooking({
    required Booking booking,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in to cancel your booking.');
    }

    if (booking.studentUid != user.uid) {
      throw Exception('You cannot cancel another student’s booking.');
    }

    final DocumentReference<Map<String, dynamic>> bookingRef =
        _bookings.doc(booking.id);

    final DocumentReference<Map<String, dynamic>> rideRef =
        _rides.doc(booking.rideId);

    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);
      final rideSnapshot = await transaction.get(rideRef);

      if (!bookingSnapshot.exists) {
        throw Exception('Booking not found.');
      }

      if (!rideSnapshot.exists) {
        throw Exception('Ride not found.');
      }

      final bookingData = bookingSnapshot.data()!;
      final rideData = rideSnapshot.data()!;

      if (bookingData['studentUid'] != user.uid) {
        throw Exception('You cannot cancel another student’s booking.');
      }

      if (bookingData['status'] != 'Confirmed') {
        throw Exception('This booking is no longer confirmed.');
      }

      if (rideData['status'] == 'Started') {
        throw Exception('A started ride cannot be cancelled.');
      }

      if (rideData['status'] == 'Cancelled') {
        throw Exception('This ride has already been cancelled.');
      }

      final int availableSeats =
          (rideData['availableSeats'] as num?)?.toInt() ?? 0;

      final int totalSeats =
          (rideData['totalSeats'] as num?)?.toInt() ?? 0;

      if (availableSeats >= totalSeats) {
        throw Exception('The ride already has all seats available.');
      }

      transaction.update(bookingRef, {
        'status': 'Cancelled',
      });

      transaction.update(rideRef, {
        'availableSeats': availableSeats + 1,
      });
    });

    await getBookings();
  }
}

