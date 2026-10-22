import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/ride_data.dart';
import '../data/student_data.dart';
import '../models/ride_model.dart';
import '../widgets/location_autocomplete_field.dart';

const Color campusRideTeal = Color(0xFF00897B);

class OfferRideScreen extends StatefulWidget {
  const OfferRideScreen({super.key});

  @override
  State<OfferRideScreen> createState() => _OfferRideScreenState();
}

class _OfferRideScreenState extends State<OfferRideScreen> {
  final TextEditingController startController =
      TextEditingController();

  final TextEditingController destinationController =
      TextEditingController();

  final TextEditingController seatsController =
      TextEditingController();

  final TextEditingController costController =
      TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  String selectedVehicle = 'Car';
  bool isSaving = false;

  Future<void> selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
    );

    if (pickedDate != null && mounted) {
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

    if (pickedTime != null && mounted) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  Future<void> offerRide() async {
    final String start = startController.text.trim();
    final String destination =
        destinationController.text.trim();

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
          content: Text(
            'Please enter a valid number of seats.',
          ),
        ),
      );
      return;
    }

    final double? cost = double.tryParse(costText);

    if (cost == null || cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid estimated cost.',
          ),
        ),
      );
      return;
    }

    final User? currentUser =
        FirebaseAuth.instance.currentUser;

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

    final String formattedTime =
        selectedTime!.format(context);

    final Ride newRide = Ride(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      rideCreatorUid: currentUser.uid,
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
      await RideData.addRide(newRide);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride offered successfully!'),
          backgroundColor: campusRideTeal,
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
        backgroundColor: campusRideTeal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            LocationAutocompleteField(
              controller: startController,
              labelText: 'Starting Point',
              hintText: 'Type a pickup location',
              prefixIcon: Icons.location_on,
            ),

            const SizedBox(height: 20),

            LocationAutocompleteField(
              controller: destinationController,
              labelText: 'Destination',
              hintText: 'Type your destination',
              prefixIcon: Icons.flag,
            ),

            const SizedBox(height: 20),

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
                        : Theme.of(context)
                            .colorScheme
                            .onSurface,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

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
                        : Theme.of(context)
                            .colorScheme
                            .onSurface,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

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

            TextField(
              controller: costController,
              keyboardType:
                  const TextInputType.numberWithOptions(
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

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isSaving ? null : offerRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: campusRideTeal,
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
