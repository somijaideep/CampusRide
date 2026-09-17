import 'package:flutter/material.dart';

import '../data/booking_data.dart';
import '../data/student_data.dart';
import '../models/booking_model.dart';
import '../models/ride_model.dart';
import 'booking_confirmation_screen.dart';

class RideDetailsScreen extends StatefulWidget {
  final Ride ride;

  const RideDetailsScreen({
    super.key,
    required this.ride,
  });

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  bool isJoining = false;

  // Convert the ride date and time into DateTime.
  DateTime? getRideDateTime() {
    try {
      final List<String> dateParts = widget.ride.date.split('/');

      if (dateParts.length != 3) {
        return null;
      }

      final int day = int.parse(dateParts[0]);
      final int month = int.parse(dateParts[1]);
      final int year = int.parse(dateParts[2]);

      final List<String> timeParts = widget.ride.time.split(' ');

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

  // Get the current ride status.
  String getRideStatus() {
    if (widget.ride.status == 'Cancelled') {
      return 'Cancelled';
    }

    if (widget.ride.status == 'Started') {
      return 'Started';
    }

    if (widget.ride.availableSeats <= 0) {
      return 'Full';
    }

    final DateTime? rideDateTime = getRideDateTime();

    if (rideDateTime != null) {
      final DateTime now = DateTime.now();

      if (!now.isBefore(rideDateTime)) {
        final DateTime waitingEnd = rideDateTime.add(
          const Duration(minutes: 10),
        );

        if (now.isBefore(waitingEnd)) {
          return 'Waiting';
        }

        return 'Waiting Ended';
      }
    }

    return 'Active';
  }

  // Join the ride and create the booking atomically.
  Future<void> joinRide() async {
    if (isJoining) {
      return;
    }

    final String status = getRideStatus();

    // Joining is not allowed after the ride has started.
    if (status == 'Started') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This ride has already started.'),
        ),
      );
      return;
    }

    // Joining is not allowed after cancellation.
    if (status == 'Cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This ride has been cancelled.'),
        ),
      );
      return;
    }

    // Joining is not allowed after the 10-minute connection period.
    if (status == 'Waiting Ended') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The 10-minute connection period has ended.',
          ),
        ),
      );
      return;
    }

    // Check whether seats are available.
    if (widget.ride.availableSeats <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sorry, no seats are available for this ride.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isJoining = true;
    });

    try {
      // Create the booking object.
      final Booking booking = Booking(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        rideId: widget.ride.id,
        studentName: StudentData.name,
        status: 'Confirmed',
      );

      // Reserve the seat AND create the booking inside
      // one Firestore transaction.
      await BookingData.createBookingWithSeat(
        booking: booking,
      );

      if (!mounted) {
        return;
      }

      // Keep the displayed ride object synchronized.
      widget.ride.availableSeats--;

      // Open confirmation screen.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingConfirmationScreen(
            ride: widget.ride,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      String message = 'Unable to join the ride.';

      final String error = e.toString();

      if (error.contains('Ride not found')) {
        message = 'This ride is no longer available.';
      } else if (error.contains('cancelled')) {
        message = 'This ride has been cancelled.';
      } else if (error.contains('already started')) {
        message = 'This ride has already started.';
      } else if (error.contains('connection period')) {
        message = 'The 10-minute connection period has ended.';
      } else if (error.contains('no seats')) {
        message = 'Sorry, no seats are available for this ride.';
      } else if (error.contains('permission-denied')) {
        message = 'You do not have permission to join this ride.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isJoining = false;
        });
      }
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Cancelled':
        return Colors.red;

      case 'Full':
        return Colors.orange;

      case 'Started':
        return Colors.blue;

      case 'Waiting':
        return Colors.deepOrange;

      case 'Waiting Ended':
        return Colors.purple;

      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int availableSeats = widget.ride.availableSeats;
    final String rideStatus = getRideStatus();
    final Color statusColor = getStatusColor(rideStatus);

    final bool isFull = availableSeats <= 0;

    final bool canJoin =
        !isJoining &&
        !isFull &&
        rideStatus != 'Cancelled' &&
        rideStatus != 'Started' &&
        rideStatus != 'Waiting Ended';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route Card
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF00897B),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.ride.pickup,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(
                        left: 12,
                        top: 5,
                        bottom: 5,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.more_vert,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.flag,
                          color: Color(0xFF00897B),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.ride.destination,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Ride Status
            const Text(
              'Ride Status',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Card(
              elevation: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Icon(
                      rideStatus == 'Started'
                          ? Icons.play_circle
                          : rideStatus == 'Cancelled'
                          ? Icons.cancel
                          : rideStatus == 'Waiting'
                          ? Icons.hourglass_top
                          : rideStatus == 'Waiting Ended'
                          ? Icons.access_time
                          : isFull
                          ? Icons.event_seat
                          : Icons.check_circle,
                      size: 45,
                      color: statusColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      rideStatus,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rideStatus == 'Waiting'
                          ? 'Connection period is active. Students can join this ride.'
                          : rideStatus == 'Waiting Ended'
                          ? 'The 10-minute connection period has ended.'
                          : rideStatus == 'Started'
                          ? 'The Ride Creator has started the ride.'
                          : rideStatus == 'Cancelled'
                          ? 'This ride has been cancelled.'
                          : isFull
                          ? 'All seats for this ride are booked.'
                          : 'This ride is available for students to join.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Ride Information
            const Text(
              'Ride Information',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _infoRow(
                      Icons.directions_car,
                      'Vehicle',
                      widget.ride.vehicleType,
                    ),
                    const Divider(),
                    _infoRow(
                      Icons.calendar_today,
                      'Date',
                      widget.ride.date,
                    ),
                    const Divider(),
                    _infoRow(
                      Icons.access_time,
                      'Time',
                      widget.ride.time,
                    ),
                    const Divider(),
                    _infoRow(
                      Icons.person,
                      'Offered by',
                      widget.ride.rideCreatorName,
                    ),
                    const Divider(),
                    _infoRow(
                      Icons.event_seat,
                      'Available Seats',
                      '$availableSeats',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Seat Status
            const Text(
              'Seat Availability',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      isFull
                          ? Icons.event_seat
                          : Icons.event_seat_outlined,
                      size: 55,
                      color: isFull
                          ? Colors.red
                          : const Color(0xFF00897B),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$availableSeats',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: isFull
                            ? Colors.red
                            : const Color(0xFF00897B),
                      ),
                    ),
                    const Text(
                      'Available Seats',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isFull
                            ? Colors.red.shade50
                            : availableSeats == 1
                            ? Colors.orange.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isFull
                            ? 'Ride Full'
                            : availableSeats == 1
                            ? '1 Seat Remaining'
                            : 'Seats Available',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isFull
                              ? Colors.red
                              : availableSeats == 1
                              ? Colors.orange.shade800
                              : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Cost Sharing
            const Text(
              'Cost Sharing',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Estimated contribution',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${widget.ride.costPerPerson.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00897B),
                      ),
                    ),
                    const Text(
                      'per person',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Estimated total cost: ₹${widget.ride.estimatedCost.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Join Ride Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: canJoin ? joinRide : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isJoining
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isFull
                            ? 'Ride Full'
                            : rideStatus == 'Waiting Ended'
                            ? 'Connection Period Ended'
                            : rideStatus == 'Started'
                            ? 'Ride Started'
                            : rideStatus == 'Cancelled'
                            ? 'Ride Cancelled'
                            : 'Join Ride',
                        style: const TextStyle(fontSize: 18),
                      ),
              ),
            ),

            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF00897B),
          size: 24,
        ),
        const SizedBox(width: 15),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.grey,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}