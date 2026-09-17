import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/booking_model.dart';

class BookingData {
  // Local list is kept temporarily so existing screens
  // can continue working while Firebase is the main
  // shared data source.
  static final List<Booking> bookings = [];

  static final CollectionReference<Map<String, dynamic>>
      _bookingsCollection =
      FirebaseFirestore.instance.collection('bookings');

  static final CollectionReference<Map<String, dynamic>>
      _ridesCollection =
      FirebaseFirestore.instance.collection('rides');

  // --------------------------------------------------
  // CREATE BOOKING + RESERVE SEAT ATOMICALLY
  // --------------------------------------------------
  //
  // The seat reservation and booking creation happen
  // inside one Firestore transaction.
  //
  // The transaction also verifies the ride's
  // 10-minute connection period.
  //
  static Future<Booking> createBookingWithSeat({
    required Booking booking,
  }) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('Student is not authenticated.');
    }

    final DocumentReference<Map<String, dynamic>> rideReference =
        _ridesCollection.doc(booking.rideId);

    final DocumentReference<Map<String, dynamic>> bookingReference =
        _bookingsCollection.doc(booking.id);

    final Booking createdBooking =
        await FirebaseFirestore.instance
            .runTransaction<Booking>((transaction) async {
      // Read the latest ride data directly from Firebase.
      final DocumentSnapshot<Map<String, dynamic>> rideSnapshot =
          await transaction.get(rideReference);

      if (!rideSnapshot.exists) {
        throw Exception('Ride not found.');
      }

      final Map<String, dynamic> rideData =
          rideSnapshot.data()!;

      final String rideStatus =
          rideData['status'] ?? 'Active';

      final int availableSeats =
          (rideData['availableSeats'] ?? 0) as int;

      // --------------------------------------------------
      // RIDE STATUS CHECKS
      // --------------------------------------------------

      // Do not allow joining a cancelled ride.
      if (rideStatus == 'Cancelled') {
        throw Exception(
          'This ride has been cancelled.',
        );
      }

      // Do not allow joining a started ride.
      if (rideStatus == 'Started') {
        throw Exception(
          'This ride has already started.',
        );
      }

      // --------------------------------------------------
      // 10-MINUTE CONNECTION PERIOD CHECK
      // --------------------------------------------------
      //
      // Before scheduled time:
      //     Joining is allowed.
      //
      // Scheduled time → +10 minutes:
      //     Joining is allowed.
      //
      // After +10 minutes:
      //     Joining is rejected.
      //

      final DateTime? rideDateTime =
          _getRideDateTime(rideData);

      if (rideDateTime != null) {
        final DateTime now = DateTime.now();

        // The connection period ends 10 minutes
        // after the scheduled ride time.
        final DateTime waitingEnd = rideDateTime.add(
          const Duration(minutes: 10),
        );

        if (!now.isBefore(waitingEnd)) {
          throw Exception(
            'The 10-minute connection period has ended.',
          );
        }
      }

      // --------------------------------------------------
      // SEAT CHECK
      // --------------------------------------------------

      // Check that a seat is still available.
      if (availableSeats <= 0) {
        throw Exception(
          'Sorry, no seats are available for this ride.',
        );
      }

      // Reduce the latest seat count.
      final int newAvailableSeats =
          availableSeats - 1;

      transaction.update(
        rideReference,
        {
          'availableSeats': newAvailableSeats,
        },
      );

      // --------------------------------------------------
      // CREATE BOOKING
      // --------------------------------------------------

      transaction.set(
        bookingReference,
        {
          'rideId': booking.rideId,
          'studentName': booking.studentName,
          'studentUid': currentUser.uid,
          'status': booking.status,
        },
      );

      return booking;
    });

    // Keep the local list synchronized.
    bookings.removeWhere(
      (existingBooking) =>
          existingBooking.id == createdBooking.id,
    );

    bookings.add(createdBooking);

    return createdBooking;
  }

  // --------------------------------------------------
  // CONVERT RIDE DATE + TIME INTO DATETIME
  // --------------------------------------------------
  //
  // Current ride format:
  // Date → DD/MM/YYYY
  // Time → HH:MM AM/PM
  //
  static DateTime? _getRideDateTime(
    Map<String, dynamic> rideData,
  ) {
    try {
      final String date =
          rideData['date'] ?? '';

      final String time =
          rideData['time'] ?? '';

      final List<String> dateParts =
          date.split('/');

      if (dateParts.length != 3) {
        return null;
      }

      final int day =
          int.parse(dateParts[0]);

      final int month =
          int.parse(dateParts[1]);

      final int year =
          int.parse(dateParts[2]);

      final List<String> timeParts =
          time.split(' ');

      if (timeParts.isEmpty) {
        return null;
      }

      final List<String> clockParts =
          timeParts[0].split(':');

      if (clockParts.length != 2) {
        return null;
      }

      int hour =
          int.parse(clockParts[0]);

      final int minute =
          int.parse(clockParts[1]);

      // Convert AM/PM to 24-hour format.
      if (timeParts.length > 1) {
        final String period =
            timeParts[1].toUpperCase();

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

  // --------------------------------------------------
  // SAVE BOOKING
  // --------------------------------------------------
  //
  // Kept for compatibility with the existing project.
  //
  static Future<void> addBooking(Booking booking) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('Student is not authenticated.');
    }

    await _bookingsCollection.doc(booking.id).set({
      'rideId': booking.rideId,
      'studentName': booking.studentName,
      'studentUid': currentUser.uid,
      'status': booking.status,
    });

    bookings.removeWhere(
      (existingBooking) =>
          existingBooking.id == booking.id,
    );

    bookings.add(booking);
  }

  // --------------------------------------------------
  // GET CURRENT STUDENT'S BOOKINGS
  // --------------------------------------------------
  static Future<List<Booking>> getBookings() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('Student is not authenticated.');
    }

    final snapshot = await _bookingsCollection
        .where(
          'studentUid',
          isEqualTo: currentUser.uid,
        )
        .get();

    final firebaseBookings =
        snapshot.docs.map((doc) {
      final Map<String, dynamic> data = doc.data();

      return Booking(
        id: doc.id,
        rideId: data['rideId'] ?? '',
        studentName: data['studentName'] ?? '',
        status: data['status'] ?? 'Confirmed',
      );
    }).toList();

    bookings
      ..clear()
      ..addAll(firebaseBookings);

    return firebaseBookings;
  }

  // --------------------------------------------------
  // UPDATE BOOKING
  // --------------------------------------------------
  static Future<void> updateBooking(
    Booking booking,
  ) async {
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('Student is not authenticated.');
    }

    await _bookingsCollection.doc(booking.id).update({
      'rideId': booking.rideId,
      'studentName': booking.studentName,
      'studentUid': currentUser.uid,
      'status': booking.status,
    });

    final index = bookings.indexWhere(
      (existingBooking) =>
          existingBooking.id == booking.id,
    );

    if (index != -1) {
      bookings[index] = booking;
    }
  }

  // --------------------------------------------------
  // CANCEL BOOKING + RETURN SEAT ATOMICALLY
  // --------------------------------------------------
  //
  // The booking cancellation and seat return happen
  // inside one Firestore transaction.
  //
  static Future<void> cancelBooking({
    required Booking booking,
  }) async {
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('Student is not authenticated.');
    }

    final DocumentReference<Map<String, dynamic>>
        bookingReference =
        _bookingsCollection.doc(booking.id);

    final DocumentReference<Map<String, dynamic>>
        rideReference =
        _ridesCollection.doc(booking.rideId);

    await FirebaseFirestore.instance
        .runTransaction<void>((transaction) async {
      // Read the latest booking.
      final DocumentSnapshot<Map<String, dynamic>>
          bookingSnapshot =
          await transaction.get(bookingReference);

      if (!bookingSnapshot.exists) {
        throw Exception('Booking not found.');
      }

      final Map<String, dynamic> bookingData =
          bookingSnapshot.data()!;

      final String bookingStudentUid =
          bookingData['studentUid'] ?? '';

      final String bookingStatus =
          bookingData['status'] ?? 'Confirmed';

      // Make sure this booking belongs to the
      // currently authenticated student.
      if (bookingStudentUid != currentUser.uid) {
        throw Exception(
          'You cannot cancel this booking.',
        );
      }

      if (bookingStatus == 'Cancelled') {
        throw Exception(
          'This booking is already cancelled.',
        );
      }

      // Read the latest ride.
      final DocumentSnapshot<Map<String, dynamic>>
          rideSnapshot =
          await transaction.get(rideReference);

      if (!rideSnapshot.exists) {
        throw Exception('Ride not found.');
      }

      final Map<String, dynamic> rideData =
          rideSnapshot.data()!;

      final int availableSeats =
          (rideData['availableSeats'] ?? 0) as int;

      final int totalSeats =
          (rideData['totalSeats'] ?? 0) as int;

      // Never allow available seats to exceed
      // the original total.
      final int newAvailableSeats =
          availableSeats < totalSeats
              ? availableSeats + 1
              : availableSeats;

      // Return the seat.
      transaction.update(
        rideReference,
        {
          'availableSeats': newAvailableSeats,
        },
      );

      // Mark the booking as cancelled.
      transaction.update(
        bookingReference,
        {
          'status': 'Cancelled',
        },
      );
    });

    // Update local copy.
    booking.status = 'Cancelled';

    final int index = bookings.indexWhere(
      (existingBooking) =>
          existingBooking.id == booking.id,
    );

    if (index != -1) {
      bookings[index] = booking;
    }
  }
}