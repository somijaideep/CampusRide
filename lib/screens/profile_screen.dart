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
  bool isSavingPhone = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadProfileData();
  }

  Future<void> loadProfileData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final User? currentUser =
          FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        throw Exception('Student is not authenticated.');
      }

      // Load the authenticated student's profile information.
      await StudentData.loadStudentData();

      // Load the latest rides and bookings.
      await RideData.getRides();
      await BookingData.getBookings();

      final int offered = RideData.rides
          .where(
            (ride) =>
                ride.rideCreatorUid == currentUser.uid,
          )
          .length;

      final int joined = BookingData.bookings.length;

      if (!mounted) return;

      setState(() {
        ridesOffered = offered;
        ridesJoined = joined;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Unable to load profile data. Please try again.';
      });
    }
  }

  Future<void> editPhoneNumber() async {
    final TextEditingController controller =
        TextEditingController(text: StudentData.phone);

    final GlobalKey<FormState> formKey =
        GlobalKey<FormState>();

    final String? phoneNumber =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update Phone Number'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              maxLength: 13,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '9876543210',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final String input =
                    (value ?? '').trim();

                if (!RegExp(r'^\+?[0-9]{10,13}$')
                    .hasMatch(input)) {
                  return 'Enter a valid 10–13 digit number';
                }

                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF00897B),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(
                    dialogContext,
                    controller.text.trim(),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (phoneNumber == null || !mounted) {
      return;
    }

    setState(() {
      isSavingPhone = true;
    });

    try {
      await StudentData.savePhone(phoneNumber);

      if (!mounted) return;

      setState(() {
        isSavingPhone = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone number updated successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSavingPhone = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to logout. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> confirmLogout() async {
    final bool? shouldLogout =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF00897B),
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      await logout();
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Profile avatar.
              const CircleAvatar(
                radius: 52,
                backgroundColor: Color(0xFFE0F2F1),
                child: Icon(
                  Icons.person,
                  size: 62,
                  color: Color(0xFF00897B),
                ),
              ),

              const SizedBox(height: 16),

              // Actual student name.
              Text(
                StudentData.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              // Actual authenticated email.
              Text(
                StudentData.email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 16),

              // Student verification badge.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified,
                      color: Color(0xFF00897B),
                      size: 19,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'VIT-AP Student Verified',
                      style: TextStyle(
                        color: Color(0xFF00897B),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Student information heading.
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Student Information',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Student details card.
              Card(
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _buildInfoTile(
                      icon: Icons.badge_outlined,
                      title: 'Registration Number',
                      value: StudentData.registrationNumber
                              .isNotEmpty
                          ? StudentData.registrationNumber
                          : 'Not available in email',
                    ),

                    const Divider(height: 1),

                    _buildInfoTile(
                      icon: Icons.email_outlined,
                      title: 'VIT-AP Email',
                      value: StudentData.email,
                    ),

                    const Divider(height: 1),

                    ListTile(
                      leading: const Icon(
                        Icons.phone_outlined,
                        color: Color(0xFF00897B),
                      ),
                      title: const Text(
                        'Phone Number',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        StudentData.phone.isNotEmpty
                            ? StudentData.phone
                            : 'Add your phone number',
                      ),
                      trailing: isSavingPhone
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00897B),
                              ),
                            )
                          : const Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF00897B),
                            ),
                      onTap: isSavingPhone
                          ? null
                          : editPhoneNumber,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Ride statistics and loading/error states.
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: CircularProgressIndicator(
                    color: Color(0xFF00897B),
                  ),
                )
              else if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),
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
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                        ),
                      ),
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
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.person,
                        number: ridesJoined.toString(),
                        label: 'Rides Joined',
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 24),

              // My Bookings.
              _buildNavigationCard(
                icon: Icons.book_online,
                title: 'My Bookings',
                subtitle: 'View your confirmed rides',
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

              const SizedBox(height: 12),

              // My Offered Rides.
              _buildNavigationCard(
                icon: Icons.directions_car,
                title: 'My Offered Rides',
                subtitle: 'View rides you have offered',
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

              const SizedBox(height: 24),

              // Logout.
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: confirmLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00897B),
                    side: const BorderSide(
                      color: Color(0xFF00897B),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: const Color(0xFF00897B),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(value),
    );
  }

  Widget _buildNavigationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE0F2F1),
          child: Icon(
            icon,
            color: const Color(0xFF00897B),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 17,
        ),
        onTap: onTap,
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 8,
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
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

