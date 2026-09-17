import 'package:flutter/material.dart';

import '../models/ride_model.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final Ride ride;

  const BookingConfirmationScreen({
    super.key,
    required this.ride,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmed'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),

            // Success icon
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.shade100,
              ),
              child: const Icon(
                Icons.check,
                size: 55,
                color: Colors.green,
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Ride Confirmed!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Your seat has been reserved successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 35),

            // Ride summary
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _infoRow(
                      Icons.location_on,
                      'Route',
                      '${ride.pickup} → ${ride.destination}',
                    ),

                    const Divider(),

                    _infoRow(
                      Icons.calendar_today,
                      'Date',
                      ride.date,
                    ),

                    const Divider(),

                    _infoRow(
                      Icons.access_time,
                      'Time',
                      ride.time,
                    ),

                    const Divider(),

                    _infoRow(
                      Icons.directions_car,
                      'Vehicle',
                      ride.vehicleType,
                    ),

                    const Divider(),

                    _infoRow(
                      Icons.person,
                      'Offered by',
                      ride.rideCreatorName,
                    ),

                    const Divider(),

                    _infoRow(
                      Icons.currency_rupee,
                      'Your contribution',
                      '₹${ride.costPerPerson.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Done button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(
                    context,
                    (route) => route.isFirst,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 18,
                  ),
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
          size: 23,
        ),

        const SizedBox(width: 15),

        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),

        const Spacer(),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}