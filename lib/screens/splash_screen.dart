import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/student_data.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(
      const Duration(seconds: 3),
      _checkLoginStatus,
    );
  }

  void _checkLoginStatus() {
    if (!mounted) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // Restore the authenticated student's email.
      StudentData.email =
          currentUser.email ?? StudentData.email;

      // Restore the registration number from the VIT-AP email.
      final String email = currentUser.email ?? '';

      if (email.contains('@')) {
        final String username = email.split('@').first;

        if (username.contains('.')) {
          StudentData.registrationNumber =
              username.split('.').last;
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00897B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 80,
            ),

            const SizedBox(height: 20),

            const Text(
              'CampusRide',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Connecting Students. One Ride at a Time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 30),

            const CircularProgressIndicator(
              color: Colors.white,
            ),

            const SizedBox(height: 15),

            const Text(
              'Preparing your journey...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}