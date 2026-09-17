import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/student_data.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();

  String? errorMessage;
  bool isLoading = false;

  Future<void> login() async {
    final String email = emailController.text.trim().toLowerCase();

    // Check whether email is empty.
    if (email.isEmpty) {
      setState(() {
        errorMessage = 'Please enter your VIT-AP email address.';
      });
      return;
    }

    // Check VIT-AP student email.
    if (!email.endsWith('@vitapstudent.ac.in')) {
      setState(() {
        errorMessage =
            'Please enter a valid VIT-AP student email address.';
      });
      return;
    }

    // Make sure the email has something before @.
    final String username = email.split('@').first;

    if (username.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a valid VIT-AP email address.';
      });
      return;
    }

    setState(() {
      errorMessage = null;
      isLoading = true;
    });

    try {
      /*
       * Firebase Authentication currently needs a password.
       *
       * For our development version, we create/sign in the student
       * using a temporary password generated from the email.
       *
       * Later, we can replace this with proper VIT-AP email
       * verification / OTP authentication.
       */
      final String temporaryPassword =
          'CampusRide@${username.hashCode.abs()}';

      UserCredential userCredential;

      try {
        // Try to create a new Firebase account.
        userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: email,
          password: temporaryPassword,
        );
      } on FirebaseAuthException catch (e) {
        // If the account already exists, sign in instead.
        if (e.code == 'email-already-in-use') {
          userCredential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(
            email: email,
            password: temporaryPassword,
          );
        } else {
          rethrow;
        }
      }

      // Make sure Firebase returned a signed-in user.
      if (userCredential.user == null) {
        throw Exception('Firebase authentication failed.');
      }

      // Save current student's information locally.
      StudentData.email = email;

      // Example:
      // pavan.24bcs7098@vitapstudent.ac.in
      //
      // username = pavan.24bcs7098
      //
      // registration number = 24bcs7098
      StudentData.registrationNumber = username.split('.').last;

      // Current demo student name.
      StudentData.name = 'CampusRide Student';

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'VIT-AP student authentication successful!',
          ),
          backgroundColor: Color(0xFF00897B),
        ),
      );

      // Go to Home Screen.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      String message = 'Authentication failed. Please try again.';

      if (e.code == 'invalid-credential') {
        message =
            'Authentication details are invalid. Please try again.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'weak-password') {
        message = 'Unable to create the student account.';
      } else if (e.code == 'network-request-failed') {
        message =
            'Network connection failed. Please check your internet.';
      }

      setState(() {
        isLoading = false;
        errorMessage = message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage =
            'Something went wrong. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F4FA),
      appBar: AppBar(
        title: const Text('CampusRide'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),

              // Login icon.
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(45),
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 50,
                    color: Color(0xFF00897B),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Heading.
              const Center(
                child: Text(
                  'Welcome to CampusRide',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Center(
                child: Text(
                  'Connect with students travelling your way.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Email label.
              const Text(
                'VIT-AP Student Email',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              // Email field.
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText:
                      'student.regno@vitapstudent.ac.in',
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF00897B),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(12),
                    ),
                    borderSide: BorderSide(
                      color: Color(0xFF00897B),
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  if (errorMessage != null) {
                    setState(() {
                      errorMessage = null;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              // Email format information.
              const Text(
                'Use your official VIT-AP student email address.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),

              // Error message.
              if (errorMessage != null) ...[
                const SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // Login button.
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : login,
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login),
                  label: Text(
                    isLoading
                        ? 'Verifying...'
                        : 'Continue',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // Verification information.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: Color(0xFF00897B),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Only VIT-AP student email addresses '
                        'are allowed to access CampusRide.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF00695C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}