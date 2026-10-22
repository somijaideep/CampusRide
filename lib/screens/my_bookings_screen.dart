import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/booking_data.dart';
import '../data/chat_data.dart';
import '../data/ride_data.dart';
import '../models/booking_model.dart';
import '../models/ride_model.dart';
import 'chat_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  bool isLoading = true;
  final Set<String> openingChats = {};

  static const Color primaryColor = Color(0xFF00897B);

  @override
  void initState() {
    super.initState();
    loadBookings();
  }

  Future<void> loadBookings() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      await RideData.getRides();
      await BookingData.getBookings();

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

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

  String getRideStatus(Ride ride) {
    if (ride.status == 'Cancelled') return 'Cancelled';
    if (ride.status == 'Started') return 'Started';

    if (ride.availableSeats <= 0) return 'Full';

    try {
      final dateParts = ride.date.split('/');

      if (dateParts.length == 3) {
        final day = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final year = int.parse(dateParts[2]);

        final timeParts = ride.time.split(' ');
        final clockParts = timeParts[0].split(':');

        int hour = int.parse(clockParts[0]);
        final minute = int.parse(clockParts[1]);

        if (timeParts.length > 1) {
          final period = timeParts[1].toUpperCase();

          if (period == 'PM' && hour != 12) {
            hour += 12;
          }

          if (period == 'AM' && hour == 12) {
            hour = 0;
          }
        }

        final rideDateTime = DateTime(
          year,
          month,
          day,
          hour,
          minute,
        );

        final now = DateTime.now();

        if (now.isBefore(rideDateTime)) {
          return 'Active';
        }

        final waitingEnd = rideDateTime.add(
          const Duration(minutes: 10),
        );

        if (now.isBefore(waitingEnd)) {
          return 'Waiting';
        }

        return 'Waiting Ended';
      }
    } catch (_) {
      // Use the default status if date/time parsing fails.
    }

    return 'Active';
  }

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
        return primaryColor;
    }
  }

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

  String getStatusMessage(String status) {
    switch (status) {
      case 'Cancelled':
        return 'This booking or ride has been cancelled.';
      case 'Started':
        return 'The Ride Creator has started the ride.';
      case 'Waiting':
        return 'The 10-minute connection period is active.';
      case 'Waiting Ended':
        return 'The connection period has ended. Waiting for the Ride Creator.';
      case 'Full':
        return 'The ride is currently full.';
      default:
        return 'Your booking is active. The ride has not reached its scheduled time yet.';
    }
  }

  Future<void> openChat(Booking booking, Ride ride) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to use chat.'),
        ),
      );
      return;
    }

    if (booking.status != 'Confirmed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat is available only for confirmed bookings.'),
        ),
      );
      return;
    }

    if (ride.status == 'Cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat is unavailable because this ride was cancelled.'),
        ),
      );
      return;
    }

    if (user.uid == ride.rideCreatorUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This chat is for the passenger.'),
        ),
      );
      return;
    }

    if (booking.studentUid != user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot open another student’s booking chat.'),
        ),
      );
      return;
    }

    if (openingChats.contains(booking.id)) return;

    setState(() {
      openingChats.add(booking.id);
    });

    try {
      final chatId = await ChatData.createOrGetChat(
        rideId: ride.id,
        bookingId: booking.id,
        rideCreatorUid: ride.rideCreatorUid,
        rideCreatorName: ride.rideCreatorName,
        studentUid: booking.studentUid,
        studentName: booking.studentName,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherStudentName: ride.rideCreatorName,
            rideId: ride.id,
            bookingId: booking.id,
            rideCreatorUid: ride.rideCreatorUid,
            rideCreatorName: ride.rideCreatorName,
            studentUid: booking.studentUid,
            studentName: booking.studentName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open chat: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          openingChats.remove(booking.id);
        });
      }
    }
  }

  Future<void> cancelBooking(int index) async {
    final Booking booking = BookingData.bookings[index];

    if (booking.status == 'Cancelled') return;

    final Ride? ride = RideData.rides.cast<Ride?>().firstWhere(
          (item) => item?.id == booking.rideId,
          orElse: () => null,
        );

    if (ride == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride not found.')),
      );
      return;
    }

    final rideStatus = getRideStatus(ride);

    if (rideStatus == 'Started') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Started rides cannot be cancelled.'),
        ),
      );
      return;
    }

    if (rideStatus == 'Cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This ride has already been cancelled.'),
        ),
      );
      return;
    }

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text(
          'Are you sure you want to cancel this booking?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;

    try {
      await BookingData.cancelBooking(booking: booking);

      if (!mounted) return;

      await RideData.getRides();
      await BookingData.getBookings();

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully!'),
          backgroundColor: primaryColor,
        ),
      );
    } catch (_) {
      try {
        await RideData.getRides();
        await BookingData.getBookings();
      } catch (_) {}

      if (!mounted) return;

      setState(() {});

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
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh bookings',
            onPressed: loadBookings,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : BookingData.bookings.isEmpty
              ? const Center(
                  child: Text(
                    'No bookings yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: BookingData.bookings.length,
                    itemBuilder: (context, index) {
                      final booking = BookingData.bookings[index];

                      final Ride? ride =
                          RideData.rides.cast<Ride?>().firstWhere(
                                (item) => item?.id == booking.rideId,
                                orElse: () => null,
                              );

                      String status = booking.status;

                      if (booking.status != 'Cancelled' && ride != null) {
                        status = getRideStatus(ride);
                      }

                      final statusColor = getStatusColor(status);
                      final statusIcon = getStatusIcon(status);

                      final isCancelled = booking.status == 'Cancelled' ||
                          ride?.status == 'Cancelled';
                      final isStarted = status == 'Started';
                      final canChat = booking.status == 'Confirmed' &&
                          ride != null &&
                          ride.status != 'Cancelled' &&
                          FirebaseAuth.instance.currentUser?.uid ==
                              booking.studentUid;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
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

                              Row(
                                children: [
                                  const Icon(Icons.person),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Student: ${booking.studentName}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              if (ride != null) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.route),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '${ride.pickup} → ${ride.destination}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Wrap(
                                  spacing: 18,
                                  runSpacing: 10,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(ride.date),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.access_time,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(ride.time),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    const Icon(Icons.directions_car),
                                    const SizedBox(width: 10),
                                    Text(
                                      ride.vehicleType,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    const Icon(Icons.person_outline),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Ride Creator: ${ride.rideCreatorName}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    const Icon(Icons.currency_rupee),
                                    const SizedBox(width: 10),
                                    Text(
                                      '₹${ride.costPerPerson.toStringAsFixed(0)} / person',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 18),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.25),
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
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (canChat) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: openingChats.contains(booking.id)
                                        ? null
                                        : () => openChat(booking, ride),
                                    icon: openingChats.contains(booking.id)
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.chat_bubble_outline),
                                    label: Text(
                                      openingChats.contains(booking.id)
                                          ? 'Opening Chat...'
                                          : 'Chat with Ride Creator',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              if (booking.status == 'Confirmed' &&
                                  !isCancelled &&
                                  !isStarted) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 45,
                                  child: OutlinedButton(
                                    onPressed: () => cancelBooking(index),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel Booking',
                                      style: TextStyle(fontSize: 16),
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
                ),
    );
  }
}