import 'package:flutter/material.dart';

import '../data/ride_data.dart';
import '../models/ride_model.dart';
import 'ride_details_screen.dart';

class FindRideScreen extends StatefulWidget {
  const FindRideScreen({super.key});

  @override
  State<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends State<FindRideScreen> {
  final TextEditingController startController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  List<Ride> searchResults = [];
  bool isSearching = false;

  Future<void> searchRide() async {
    String start = startController.text.trim().toLowerCase();
    String destination = destinationController.text.trim().toLowerCase();

    if (start.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter starting point and destination.'),
        ),
      );
      return;
    }

    setState(() {
      isSearching = true;
    });

    try {
      // Get the latest rides from Firebase Firestore.
      final List<Ride> allRides = await RideData.getRides();

      // Search rides from the Firebase data.
      // Full rides are also included so the user can see
      // that the ride is full.
      List<Ride> results = allRides.where((ride) {
        return ride.pickup.toLowerCase() == start &&
            ride.destination.toLowerCase() == destination;
      }).toList();

      if (!mounted) return;

      setState(() {
        searchResults = results;
        isSearching = false;
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No matching rides found.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSearching = false;
        searchResults = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load rides. Please check your connection.\n$e',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    startController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Ride'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Starting Point
            TextField(
              controller: startController,
              decoration: const InputDecoration(
                labelText: 'Starting Point',
                hintText: 'Example: Vijayawada',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 20),

            // Destination
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination',
                hintText: 'Example: VIT-AP',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 30),

            // Search button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isSearching ? null : searchRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                ),
                child: isSearching
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Search Rides',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),

            const SizedBox(height: 30),

            // Search results
            if (searchResults.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Matching Rides',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),

                  ...searchResults.map(
                    (ride) => RideCard(ride: ride),
                  ),
                ],
              ),

            // No rides found
            if (searchResults.isEmpty &&
                startController.text.isNotEmpty &&
                destinationController.text.isNotEmpty &&
                !isSearching)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  'No rides to display.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class RideCard extends StatelessWidget {
  final Ride ride;

  const RideCard({
    super.key,
    required this.ride,
  });

  // Convert ride date and time into DateTime.
  DateTime? getRideDateTime() {
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

  // Get the current display status.
  String getRideStatus() {
    if (ride.status == 'Cancelled') {
      return 'Cancelled';
    }

    if (ride.status == 'Started') {
      return 'Started';
    }

    if (ride.availableSeats <= 0) {
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
    final bool isFull = ride.availableSeats <= 0;

    final String status = getRideStatus();
    final Color statusColor = getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle
            Row(
              children: [
                Icon(
                  status == 'Started'
                      ? Icons.play_circle
                      : status == 'Cancelled'
                      ? Icons.cancel
                      : status == 'Waiting'
                      ? Icons.hourglass_top
                      : status == 'Waiting Ended'
                      ? Icons.access_time
                      : Icons.directions_car,
                  size: 30,
                  color: statusColor,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    ride.vehicleType,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
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
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // Route
            Text(
              '${ride.pickup} → ${ride.destination}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // Date and time
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                ),

                const SizedBox(width: 8),

                Text(ride.date),

                const SizedBox(width: 20),

                const Icon(
                  Icons.access_time,
                  size: 18,
                ),

                const SizedBox(width: 8),

                Text(ride.time),
              ],
            ),

            const SizedBox(height: 10),

            // Ride Creator
            Row(
              children: [
                const Icon(
                  Icons.person,
                  size: 20,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    'Offered by: ${ride.rideCreatorName}',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Seats
            Row(
              children: [
                Icon(
                  Icons.event_seat,
                  size: 20,
                  color: isFull
                      ? Colors.red
                      : const Color(0xFF00897B),
                ),

                const SizedBox(width: 8),

                Text(
                  isFull
                      ? '0 seat(s) available • RIDE FULL'
                      : '${ride.availableSeats} seat(s) available',
                  style: TextStyle(
                    fontWeight: isFull
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isFull
                        ? Colors.red
                        : Colors.black,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Status explanation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                status == 'Waiting'
                    ? 'Connection period is active. Students can join this ride.'
                    : status == 'Waiting Ended'
                    ? 'The 10-minute connection period has ended. Waiting for the Ride Creator to start or cancel.'
                    : status == 'Started'
                    ? 'This ride has been started by the Ride Creator.'
                    : status == 'Cancelled'
                    ? 'This ride has been cancelled.'
                    : isFull
                    ? 'All seats for this ride are booked.'
                    : 'This ride is available for students.',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const Divider(height: 25),

            // Cost
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated share',
                  style: TextStyle(fontSize: 15),
                ),

                Text(
                  '₹${ride.costPerPerson.toStringAsFixed(0)} / person',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00897B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // View Ride button
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RideDetailsScreen(ride: ride),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFull
                      ? Colors.grey
                      : const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  isFull
                      ? 'View Full Ride'
                      : 'View Ride',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}