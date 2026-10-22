import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/booking_data.dart';
import '../data/chat_data.dart';
import '../data/ride_data.dart';
import '../models/ride_model.dart';
import 'chat_screen.dart';

class MyOfferedRidesScreen extends StatefulWidget {
  const MyOfferedRidesScreen({super.key});

  @override
  State<MyOfferedRidesScreen> createState() =>
      _MyOfferedRidesScreenState();
}

class _MyOfferedRidesScreenState extends State<MyOfferedRidesScreen> {
  bool isLoading = true;

  String? updatingRideId;

  // Cache passenger requests to avoid repeated Firestore queries
  // whenever Flutter rebuilds the screen.
  final Map<String, Future<List<Map<String, dynamic>>>>
      _passengerFutures = {};

  @override
  void initState() {
    super.initState();
    loadOfferedRides();
  }

  Future<void> loadOfferedRides() async {
    try {
      await RideData.getRides();

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
        SnackBar(
          content: Text(
            'Could not load your rides. Please check your connection.\n$e',
          ),
        ),
      );
    }
  }

  // Retrieve confirmed passengers for one ride.
  Future<List<Map<String, dynamic>>> _getPassengers(
    String rideId,
  ) {
    return _passengerFutures.putIfAbsent(
      rideId,
      () => BookingData.getConfirmedPassengers(rideId),
    );
  }

  // Open a private chat between the ride creator and a passenger.
  Future<void> _openPassengerChat({
    required Ride ride,
    required Map<String, dynamic> passenger,
  }) async {
    final String bookingId =
        (passenger['bookingId'] ?? '').toString();

    final String studentUid =
        (passenger['studentUid'] ?? '').toString();

    final String studentName =
        (passenger['studentName'] ?? 'Student').toString();

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to use chat.'),
        ),
      );
      return;
    }

    if (currentUser.uid != ride.rideCreatorUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the ride creator can use this action here.'),
        ),
      );
      return;
    }

    if (bookingId.isEmpty || studentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Passenger information is incomplete. Please refresh and try again.',
          ),
        ),
      );
      return;
    }

    try {
      final String chatId = await ChatData.createOrGetChat(
        rideId: ride.id,
        bookingId: bookingId,
        rideCreatorUid: ride.rideCreatorUid,
        rideCreatorName: ride.rideCreatorName,
        studentUid: studentUid,
        studentName: studentName,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherStudentName: studentName,
            rideId: ride.id,
            bookingId: bookingId,
            rideCreatorUid: ride.rideCreatorUid,
            rideCreatorName: ride.rideCreatorName,
            studentUid: studentUid,
            studentName: studentName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open the chat. Check your connection and Firestore rules.\n$e',
          ),
        ),
      );
    }
  }

  // Cancel a ride.
  Future<void> cancelRide(Ride ride) async {
    if (updatingRideId != null) return;

    if (ride.status == 'Cancelled') return;

    if (ride.status == 'Started') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A started ride cannot be cancelled.'),
        ),
      );
      return;
    }

    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Ride?'),
          content: Text(
            'Are you sure you want to cancel the ride from '
            '${ride.pickup} to ${ride.destination}?',
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
              child: const Text('Cancel Ride'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true || !mounted) return;

    setState(() {
      updatingRideId = ride.id;
    });

    try {
      ride.status = 'Cancelled';

      await RideData.updateRide(ride);
      await RideData.getRides();

      if (!mounted) return;

      setState(() {
        updatingRideId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride cancelled successfully!'),
          backgroundColor: Color(0xFF00897B),
        ),
      );
    } catch (e) {
      try {
        await RideData.getRides();
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        updatingRideId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel the ride.\n$e'),
        ),
      );
    }
  }

  // Start the ride.
  Future<void> startRide(Ride ride) async {
    if (updatingRideId != null) return;

    if (ride.status == 'Cancelled' || ride.status == 'Started') {
      return;
    }

    final String currentStatus = getRideStatus(ride);

    if (currentStatus == 'Active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The ride can be started at the scheduled time.',
          ),
        ),
      );
      return;
    }

    if (currentStatus != 'Waiting' &&
        currentStatus != 'Waiting Ended' &&
        currentStatus != 'Full') {
      return;
    }

    final bool? shouldStart = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start Ride?'),
          content: Text(
            'Start the ride from ${ride.pickup} to '
            '${ride.destination}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Not Yet'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Ride'),
            ),
          ],
        );
      },
    );

    if (shouldStart != true || !mounted) return;

    setState(() {
      updatingRideId = ride.id;
    });

    try {
      ride.status = 'Started';

      await RideData.updateRide(ride);
      await RideData.getRides();

      if (!mounted) return;

      setState(() {
        updatingRideId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride started successfully!'),
          backgroundColor: Color(0xFF00897B),
        ),
      );
    } catch (e) {
      try {
        await RideData.getRides();
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        updatingRideId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start the ride.\n$e'),
        ),
      );
    }
  }

  // Convert the ride date and time into DateTime.
  DateTime? getRideDateTime(Ride ride) {
    try {
      final List<String> dateParts = ride.date.split('/');

      if (dateParts.length != 3) return null;

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

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  // Get the current display status of the ride.
  String getRideStatus(Ride ride) {
    if (ride.status == 'Cancelled') return 'Cancelled';
    if (ride.status == 'Started') return 'Started';

    final DateTime? rideDateTime = getRideDateTime(ride);

    if (rideDateTime != null) {
      final DateTime now = DateTime.now();

      if (now.isBefore(rideDateTime)) {
        return ride.availableSeats <= 0 ? 'Full' : 'Active';
      }

      final DateTime waitingEnd =
          rideDateTime.add(const Duration(minutes: 10));

      if (now.isBefore(waitingEnd)) return 'Waiting';

      return 'Waiting Ended';
    }

    return ride.availableSeats <= 0 ? 'Full' : 'Active';
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

  // Passenger section for a ride.
  Widget _buildPassengersSection(Ride ride) {
    if (ride.status == 'Cancelled') {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 18),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.grey),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chat is unavailable because this ride was cancelled.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.groups_outlined,
                color: Color(0xFF00897B),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confirmed Passengers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getPassengers(ride.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00897B),
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Could not load passengers.',
                      style: TextStyle(color: Colors.red),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _passengerFutures.remove(ride.id);
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                );
              }

              final List<Map<String, dynamic>> passengers =
                  snapshot.data ?? [];

              if (passengers.isEmpty) {
                return const Text(
                  'No confirmed passengers yet.',
                  style: TextStyle(color: Colors.black54),
                );
              }

              return Column(
                children: passengers.map((passenger) {
                  final String name =
                      (passenger['studentName'] ?? 'Student').toString();

                  final bool canChat =
                      (passenger['studentUid'] ?? '')
                          .toString()
                          .isNotEmpty &&
                      (passenger['bookingId'] ?? '')
                          .toString()
                          .isNotEmpty;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFE0F2F1),
                          child: Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              color: Color(0xFF00897B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: canChat
                              ? () => _openPassengerChat(
                                    ride: ride,
                                    passenger: passenger,
                                  )
                              : null,
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            size: 18,
                          ),
                          label: const Text('Chat'),
                          style: FilledButton.styleFrom(
                            foregroundColor: const Color(0xFF00897B),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Offered Rides'),
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00897B),
          ),
        ),
      );
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;

    final List<Ride> offeredRides = currentUser == null
        ? []
        : RideData.rides
            .where((ride) => ride.rideCreatorUid == currentUser.uid)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Offered Rides'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: offeredRides.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.directions_car_outlined,
                      size: 80,
                      color: Color(0xFF00897B),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Offered Rides',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'You have not offered any rides yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: offeredRides.length,
              itemBuilder: (context, index) {
                final Ride ride = offeredRides[index];

                final String status = getRideStatus(ride);
                final Color statusColor = getStatusColor(status);

                final bool isCancelled = status == 'Cancelled';
                final bool isFull = status == 'Full';
                final bool isStarted = status == 'Started';
                final bool isWaiting = status == 'Waiting';
                final bool isWaitingEnded = status == 'Waiting Ended';

                final bool isUpdating = updatingRideId == ride.id;

                final bool canStartRide =
                    !isCancelled &&
                    !isStarted &&
                    !isUpdating &&
                    (isWaiting || isWaitingEnded || isFull);

                final bool canCancelRide =
                    !isCancelled && !isStarted && !isUpdating;

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: isCancelled
                                  ? Colors.red.shade50
                                  : const Color(0xFFE0F2F1),
                              child: Icon(
                                isCancelled
                                    ? Icons.cancel
                                    : isStarted
                                        ? Icons.play_circle
                                        : isWaiting
                                            ? Icons.hourglass_top
                                            : isWaitingEnded
                                                ? Icons.access_time
                                                : Icons.directions_car,
                                color: statusColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Ride Offered',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Color(0xFF00897B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${ride.pickup} → ${ride.destination}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.calendar_today,
                                label: 'Date',
                                value: ride.date,
                              ),
                            ),
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.access_time,
                                label: 'Time',
                                value: ride.time,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.directions_car,
                                label: 'Vehicle',
                                value: ride.vehicleType,
                              ),
                            ),
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.event_seat,
                                label: 'Available Seats',
                                value: '${ride.availableSeats}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.currency_rupee,
                                label: 'Total Cost',
                                value:
                                    '₹${ride.estimatedCost.toStringAsFixed(0)}',
                              ),
                            ),
                            Expanded(
                              child: _InfoItem(
                                icon: Icons.person,
                                label: 'Per Person',
                                value:
                                    '₹${ride.costPerPerson.toStringAsFixed(0)}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCancelled
                                    ? Icons.cancel
                                    : isStarted
                                        ? Icons.play_circle
                                        : isWaiting
                                            ? Icons.hourglass_top
                                            : isWaitingEnded
                                                ? Icons.access_time
                                                : isFull
                                                    ? Icons.event_seat
                                                    : Icons.check_circle,
                                color: statusColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isCancelled
                                      ? 'This ride has been cancelled.'
                                      : isStarted
                                          ? 'This ride has been started by the Ride Creator.'
                                          : isWaiting
                                              ? 'Connection period is active. Students can join this ride for the next 10 minutes.'
                                              : isWaitingEnded
                                                  ? 'The 10-minute connection period has ended. You can start or cancel the ride.'
                                                  : isFull
                                                      ? 'All seats for this ride are booked.'
                                                      : 'This ride is currently accepting students.',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Confirmed passengers and private chats.
                        _buildPassengersSection(ride),

                        if (isUpdating) ...[
                          const SizedBox(height: 18),
                          const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF00897B),
                            ),
                          ),
                        ],

                        if (canStartRide || canCancelRide) ...[
                          const SizedBox(height: 20),
                          if (canStartRide)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () => startRide(ride),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text(
                                  'Start Ride',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00897B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          if (canStartRide && canCancelRide)
                            const SizedBox(height: 10),
                          if (canCancelRide)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () => cancelRide(ride),
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Cancel Ride',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
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

// Reusable information item.
class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 22,
          color: Colors.grey,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}