import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/booking_data.dart';
import '../data/ride_data.dart';
import '../data/student_data.dart';
import 'login_screen.dart';
import 'my_bookings_screen.dart';
import 'my_offered_rides_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int ridesOffered = 0;
  int ridesJoined = 0;

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadProfileData();
  }

  Future<void> loadProfileData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('Student is not authenticated.');
      }

      // Load the latest rides and bookings from Firestore.
      await RideData.getRides();
      await BookingData.getBookings();

      // Count only rides created by the current student.
      final int offered = RideData.rides
          .where(
            (ride) => ride.rideCreatorUid == currentUser.uid,
          )
          .length;

      // BookingData already loads only the current student's
      // bookings, so we can use its count directly.
      final int joined = BookingData.bookings.length;

      if (!mounted) {
        return;
      }

      setState(() {
        ridesOffered = offered;
        ridesJoined = joined;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load profile data.';
      });
    }
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to logout. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: loadProfileData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              const CircleAvatar(
                radius: 55,
                backgroundColor: Color(0xFFE0F2F1),
                child: Icon(
                  Icons.person,
                  size: 65,
                  color: Color(0xFF00897B),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                StudentData.name,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                StudentData.email,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified,
                      color: Color(0xFF00897B),
                      size: 20,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'VIT-AP Student Verified',
                      style: TextStyle(
                        color: Color(0xFF00897B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Student Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.badge,
                        color: Color(0xFF00897B),
                      ),
                      title: const Text(
                        'Registration Number',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        StudentData.registrationNumber,
                      ),
                    ),

                    const Divider(height: 1),

                    ListTile(
                      leading: const Icon(
                        Icons.email,
                        color: Color(0xFF00897B),
                      ),
                      title: const Text(
                        'VIT-AP Email',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(StudentData.email),
                    ),

                    const Divider(height: 1),

                    ListTile(
                      leading: const Icon(
                        Icons.phone,
                        color: Color(0xFF00897B),
                      ),
                      title: const Text(
                        'Phone Number',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(StudentData.phone),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(
                    color: Color(0xFF00897B),
                  ),
                )
              else if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 35,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: loadProfileData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.directions_car,
                        number: ridesOffered.toString(),
                        label: 'Rides Offered',
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.person,
                        number: ridesJoined.toString(),
                        label: 'Rides Joined',
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 25),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2F1),
                    child: Icon(
                      Icons.book_online,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  title: const Text(
                    'My Bookings',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'View your confirmed rides',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MyBookingsScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE0F2F1),
                    child: Icon(
                      Icons.directions_car,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  title: const Text(
                    'My Offered Rides',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'View rides you have offered',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MyOfferedRidesScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Logout'),
                          content: const Text(
                            'Are you sure you want to logout?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(context);

                                await logout();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF00897B),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Logout'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String number,
    required String label,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 10,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 30,
              color: const Color(0xFF00897B),
            ),
            const SizedBox(height: 8),
            Text(
              number,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}