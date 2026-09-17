import 'package:flutter/material.dart';

import '../data/booking_data.dart';
import '../data/ride_data.dart';
import '../models/booking_model.dart';
import '../models/ride_model.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadBookings();
  }

  // Load bookings and rides from Firebase.
  Future<void> loadBookings() async {
    setState(() {
      isLoading = true;
    });

    try {
      await RideData.getRides();
      await BookingData.getBookings();

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load bookings from Firebase.'),
        ),
      );
    }
  }

  // Get the current status of the ride.
  String getRideStatus(Ride ride) {
    // Ride Creator cancelled the ride.
    if (ride.status == 'Cancelled') {
      return 'Cancelled';
    }

    // Ride Creator started the ride.
    if (ride.status == 'Started') {
      return 'Started';
    }

    // If all seats are booked.
    if (ride.availableSeats <= 0) {
      return 'Full';
    }

    // Check scheduled date and time.
    try {
      final List<String> dateParts = ride.date.split('/');

      if (dateParts.length == 3) {
        final int day = int.parse(dateParts[0]);
        final int month = int.parse(dateParts[1]);
        final int year = int.parse(dateParts[2]);

        final List<String> timeParts = ride.time.split(' ');
        final List<String> clockParts = timeParts[0].split(':');

        int hour = int.parse(clockParts[0]);
        final int minute = int.parse(clockParts[1]);

        // Convert AM/PM to 24-hour format.
        if (timeParts.length > 1) {
          final String period = timeParts[1].toUpperCase();

          if (period == 'PM' && hour != 12) {
            hour += 12;
          }

          if (period == 'AM' && hour == 12) {
            hour = 0;
          }
        }

        final DateTime rideDateTime = DateTime(
          year,
          month,
          day,
          hour,
          minute,
        );

        final DateTime now = DateTime.now();

        // Before scheduled time.
        if (now.isBefore(rideDateTime)) {
          return 'Active';
        }

        // 10-minute connection/waiting period.
        final DateTime waitingEnd = rideDateTime.add(
          const Duration(minutes: 10),
        );

        if (now.isBefore(waitingEnd)) {
          return 'Waiting';
        }

        // The 10-minute period ended.
        return 'Waiting Ended';
      }
    } catch (e) {
      // Continue with normal status checking.
    }

    return 'Active';
  }

  // Get color for ride status.
  Color getStatusColor(String status) {
    switch (status) {
      case 'Cancelled':
        return Colors.red;

      case 'Started':
        return Colors.blue;

      case 'Waiting':
        return Colors.deepOrange;

      case 'Waiting Ended':
        return Colors.purple;

      case 'Full':
        return Colors.orange;

      default:
        return const Color(0xFF00897B);
    }
  }

  // Get status icon.
  IconData getStatusIcon(String status) {
    switch (status) {
      case 'Cancelled':
        return Icons.cancel;

      case 'Started':
        return Icons.play_circle;

      case 'Waiting':
        return Icons.hourglass_top;

      case 'Waiting Ended':
        return Icons.access_time;

      case 'Full':
        return Icons.event_seat;

      default:
        return Icons.check_circle;
    }
  }

  // Get explanation for each ride status.
  String getStatusMessage(String status) {
    switch (status) {
      case 'Cancelled':
        return 'This booking has been cancelled.';

      case 'Started':
        return 'The Ride Creator has started the ride.';

      case 'Waiting':
        return 'The 10-minute connection period is active. Students can still join this ride.';

      case 'Waiting Ended':
        return 'The 10-minute connection period has ended. Waiting for the Ride Creator to start or cancel the ride.';

      case 'Full':
        return 'The ride is currently full.';

      default:
        return 'Your booking is active. The ride has not reached its scheduled time yet.';
    }
  }

  // Cancel booking and return the seat using ONE Firebase transaction.
  Future<void> cancelBooking(int index) async {
    final Booking booking = BookingData.bookings[index];

    // Already cancelled.
    if (booking.status == 'Cancelled') {
      return;
    }

    // Find the ride connected to this booking.
    final int rideIndex = RideData.rides.indexWhere(
      (ride) => ride.id == booking.rideId,
    );

    if (rideIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride not found.'),
        ),
      );
      return;
    }

    final Ride ride = RideData.rides[rideIndex];
    final String rideStatus = getRideStatus(ride);

    // Don't allow cancellation after the ride has started.
    if (rideStatus == 'Started') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Started rides cannot be cancelled.'),
        ),
      );
      return;
    }

    // Don't allow cancellation if Ride Creator cancelled the ride.
    if (rideStatus == 'Cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This ride has already been cancelled.',
          ),
        ),
      );
      return;
    }

    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Booking'),
          content: const Text(
            'Are you sure you want to cancel this booking?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) {
      return;
    }

    try {
      // IMPORTANT:
      // BookingData.cancelBooking() performs:
      //
      // 1. Booking → Cancelled
      // 2. Ride availableSeats → +1
      //
      // inside ONE Firebase transaction.
      //
      // This prevents the booking and seat from getting
      // out of sync if one operation fails.

      await BookingData.cancelBooking(
        booking: booking,
      );

      if (!mounted) {
        return;
      }

      // Reload the latest Firebase data.
      await RideData.getRides();
      await BookingData.getBookings();

      if (!mounted) {
        return;
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully!'),
          backgroundColor: Color(0xFF00897B),
        ),
      );
    } catch (e) {
      // Reload the latest data after any Firebase error.
      try {
        await RideData.getRides();
        await BookingData.getBookings();
      } catch (_) {}

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to cancel booking. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00897B),
              ),
            )
          : BookingData.bookings.isEmpty
          ? const Center(
              child: Text(
                'No bookings yet.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: BookingData.bookings.length,
              itemBuilder: (context, index) {
                final Booking booking = BookingData.bookings[index];

                // Find the ride connected to this booking.
                final Ride? ride =
                    RideData.rides.cast<Ride?>().firstWhere(
                      (ride) => ride?.id == booking.rideId,
                      orElse: () => null,
                    );

                // Determine displayed status.
                String status = booking.status;

                if (booking.status != 'Cancelled' &&
                    ride != null) {
                  status = getRideStatus(ride);
                }

                final Color statusColor = getStatusColor(status);
                final IconData statusIcon = getStatusIcon(status);

                final bool isCancelled = status == 'Cancelled';
                final bool isStarted = status == 'Started';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Booking title and status.
                        Row(
                          children: [
                            Icon(
                              statusIcon,
                              color: statusColor,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isCancelled
                                    ? 'Booking Cancelled'
                                    : isStarted
                                    ? 'Ride Started'
                                    : status == 'Waiting'
                                    ? 'Waiting for Connection'
                                    : status == 'Waiting Ended'
                                    ? 'Waiting for Ride Creator'
                                    : 'Booking Confirmed',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Status badge.
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Status: $status',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),

                        const Divider(height: 25),

                        // Student.
                        Row(
                          children: [
                            const Icon(Icons.person),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Student: ${booking.studentName}',
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Ride information.
                        if (ride != null) ...[
                          // Route.
                          Row(
                            children: [
                              const Icon(Icons.route),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${ride.pickup} → ${ride.destination}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Date and time.
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                ride.date,
                                style: const TextStyle(
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 20),
                              const Icon(
                                Icons.access_time,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                ride.time,
                                style: const TextStyle(
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Vehicle.
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_car,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                ride.vehicleType,
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Ride Creator.
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Ride Creator: ${ride.rideCreatorName}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Cost.
                          Row(
                            children: [
                              const Icon(
                                Icons.currency_rupee,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '₹${ride.costPerPerson.toStringAsFixed(0)} / person',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Information message.
                        const SizedBox(height: 18),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius:
                                BorderRadius.circular(10),
                            border: Border.all(
                              color: statusColor.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                statusIcon,
                                color: statusColor,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  getStatusMessage(status),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Cancel booking button.
                        if (!isCancelled && !isStarted) ...[
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: OutlinedButton(
                              onPressed: () {
                                cancelBooking(index);
                              },
                              style:
                                  OutlinedButton.styleFrom(
                                    foregroundColor:
                                        Colors.red,
                                    side:
                                        const BorderSide(
                                      color: Colors.red,
                                    ),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                        10,
                                      ),
                                    ),
                                  ),
                              child: const Text(
                                'Cancel Booking',
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}