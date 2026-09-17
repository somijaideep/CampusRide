import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/ride_data.dart';
import '../data/student_data.dart';
import '../models/ride_model.dart';

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  final TextEditingController startController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController seatsController = TextEditingController();
  final TextEditingController costController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  String selectedVehicle = 'Car';

  bool isSaving = false;

  Future<void> selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> selectTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  Future<void> offerRide() async {
    final String start = startController.text.trim();
    final String destination = destinationController.text.trim();
    final String seatsText = seatsController.text.trim();
    final String costText = costController.text.trim();

    if (start.isEmpty ||
        destination.isEmpty ||
        seatsText.isEmpty ||
        costText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields.'),
        ),
      );
      return;
    }

    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date.'),
        ),
      );
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time.'),
        ),
      );
      return;
    }

    final int? seats = int.tryParse(seatsText);

    if (seats == null || seats <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number of seats.'),
        ),
      );
      return;
    }

    final double? cost = double.tryParse(costText);

    if (cost == null || cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid estimated cost.'),
        ),
      );
      return;
    }

    // Get the currently authenticated Firebase student.
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Student is not authenticated. Please log in again.',
          ),
        ),
      );
      return;
    }

    final String formattedDate =
        '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}';

    final String formattedTime = selectedTime!.format(context);

    final Ride newRide = Ride(
      id: DateTime.now().millisecondsSinceEpoch.toString(),

      // Firebase UID identifies the student who created this ride.
      rideCreatorUid: currentUser.uid,

      // Display name of the ride creator.
      rideCreatorName: StudentData.name,

      pickup: start,
      destination: destination,
      date: formattedDate,
      time: formattedTime,
      vehicleType: selectedVehicle,
      totalSeats: seats,
      availableSeats: seats,
      estimatedCost: cost,
    );

    setState(() {
      isSaving = true;
    });

    try {
      // Save the ride to Firebase Firestore.
      await RideData.addRide(newRide);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride offered successfully!'),
          backgroundColor: Color(0xFF00897B),
        ),
      );

      startController.clear();
      destinationController.clear();
      seatsController.clear();
      costController.clear();

      setState(() {
        selectedDate = null;
        selectedTime = null;
        selectedVehicle = 'Car';
        isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save the ride. Please try again.\n$e',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    startController.dispose();
    destinationController.dispose();
    seatsController.dispose();
    costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer a Ride'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // Starting Point
            TextField(
              controller: startController,
              decoration: const InputDecoration(
                labelText: 'Starting Point',
                hintText: 'Example: VIT-AP',
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
                hintText: 'Example: Vijayawada',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
            ),

            const SizedBox(height: 20),

            // Date
            InkWell(
              onTap: selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  selectedDate == null
                      ? 'Select Date'
                      : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedDate == null
                        ? Colors.grey
                        : Colors.black,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Time
            InkWell(
              onTap: selectTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Time',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.access_time),
                ),
                child: Text(
                  selectedTime == null
                      ? 'Select Time'
                      : selectedTime!.format(context),
                  style: TextStyle(
                    fontSize: 16,
                    color: selectedTime == null
                        ? Colors.grey
                        : Colors.black,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Vehicle Type
            DropdownButtonFormField<String>(
              initialValue: selectedVehicle,
              decoration: const InputDecoration(
                labelText: 'Vehicle Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Car',
                  child: Text('Car'),
                ),
                DropdownMenuItem(
                  value: 'Bike',
                  child: Text('Bike'),
                ),
                DropdownMenuItem(
                  value: 'Auto',
                  child: Text('Auto'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedVehicle = value;
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            // Available Seats
            TextField(
              controller: seatsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Available Seats',
                hintText: 'Example: 2',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event_seat),
              ),
            ),

            const SizedBox(height: 20),

            // Estimated Cost
            TextField(
              controller: costController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Estimated Total Cost',
                hintText: 'Example: 500',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            // Offer Ride Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isSaving ? null : offerRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Offer Ride',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}