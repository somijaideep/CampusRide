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
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isRegisterMode = false;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  String? errorMessage;
  String? infoMessage;

  // --------------------------------------------------
  // VALIDATE COLLEGE EMAIL
  // --------------------------------------------------

  bool isValidCollegeEmail(String email) {
    return email.endsWith('@vitapstudent.ac.in') &&
        email.split('@').length == 2 &&
        email.split('@').first.isNotEmpty;
  }

  // --------------------------------------------------
  // SAVE STUDENT INFORMATION
  // --------------------------------------------------

  void saveStudentInformation(User user) {
    final String email = user.email ?? '';
    final String username = email.split('@').first;

    StudentData.email = email;

    if (username.contains('.')) {
      StudentData.registrationNumber =
          username.split('.').last;
    } else {
      StudentData.registrationNumber = username;
    }

    // Preserve the existing demo name.
    // We can add proper profile-name collection later.
    StudentData.name = 'CampusRide Student';
  }

  // --------------------------------------------------
  // NAVIGATE TO HOME
  // --------------------------------------------------

  void navigateToHome(User user) {
    if (!mounted) return;

    saveStudentInformation(user);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
      (route) => false,
    );
  }

  // --------------------------------------------------
  // CLEAR MESSAGES
  // --------------------------------------------------

  void clearMessages() {
    errorMessage = null;
    infoMessage = null;
  }

  // --------------------------------------------------
  // LOGIN
  // --------------------------------------------------

  Future<void> login() async {
    final String email =
        emailController.text.trim().toLowerCase();

    final String password = passwordController.text;

    if (email.isEmpty) {
      setState(() {
        clearMessages();
        errorMessage =
            'Please enter your VIT-AP student email.';
      });
      return;
    }

    if (!isValidCollegeEmail(email)) {
      setState(() {
        clearMessages();
        errorMessage =
            'Please use your @vitapstudent.ac.in email.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        clearMessages();
        errorMessage = 'Please enter your password.';
      });
      return;
    }

    setState(() {
      clearMessages();
      isLoading = true;
    });

    try {
      final UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Unable to retrieve the account.',
        );
      }

      // Refresh the user's verification status.
      await user.reload();

      user = _auth.currentUser;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Please sign in again.',
        );
      }

      if (!user.emailVerified) {
        // Send a verification email if the account
        // has not yet been verified.
        await user.sendEmailVerification();

        // Do not leave an unverified account signed in.
        await _auth.signOut();

        if (!mounted) return;

        setState(() {
          isLoading = false;
          infoMessage =
              'Your email is not verified yet. '
              'We have sent a verification email. '
              'Open the link in your email, then sign in again.';
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      navigateToHome(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message =
              'No account was found. Please create an account first.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message =
              'Incorrect email or password. '
              'If this is an older account, try Forgot Password.';
          break;

        case 'user-disabled':
          message =
              'This account has been disabled. Contact support.';
          break;

        case 'too-many-requests':
          message =
              'Too many attempts. Please wait and try again later.';
          break;

        case 'network-request-failed':
          message =
              'Network error. Please check your internet connection.';
          break;

        case 'operation-not-allowed':
          message =
              'Email/password authentication is not enabled in Firebase.';
          break;

        default:
          message =
              'Login failed. Please try again. (${e.code})';
      }

      setState(() {
        isLoading = false;
        errorMessage = message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Something went wrong. Please try again.';
      });
    }
  }

  // --------------------------------------------------
  // REGISTER
  // --------------------------------------------------

  Future<void> register() async {
    final String email =
        emailController.text.trim().toLowerCase();

    final String password = passwordController.text;

    final String confirmPassword =
        confirmPasswordController.text;

    if (email.isEmpty) {
      setState(() {
        clearMessages();
        errorMessage = 'Please enter your college email.';
      });
      return;
    }

    if (!isValidCollegeEmail(email)) {
      setState(() {
        clearMessages();
        errorMessage =
            'Registration requires an @vitapstudent.ac.in email.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        clearMessages();
        errorMessage = 'Please create a password.';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        clearMessages();
        errorMessage =
            'Your password must contain at least 6 characters.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        clearMessages();
        errorMessage = 'The passwords do not match.';
      });
      return;
    }

    setState(() {
      clearMessages();
      isLoading = true;
    });

    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Unable to create the account.',
        );
      }

      // Send the verification email.
      await user.sendEmailVerification();

      // Sign out until the student verifies the email.
      await _auth.signOut();

      if (!mounted) return;

      setState(() {
        isLoading = false;
        isRegisterMode = false;
        passwordController.clear();
        confirmPasswordController.clear();

        infoMessage =
            'Account created successfully! '
            'Check your college email and click the '
            'verification link before signing in.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'An account already exists for this email. '
              'Please sign in or reset your password.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'weak-password':
          message =
              'Choose a stronger password with at least 6 characters.';
          break;

        case 'operation-not-allowed':
          message =
              'Email/password authentication is not enabled in Firebase.';
          break;

        case 'too-many-requests':
          message =
              'Too many attempts. Please wait before trying again.';
          break;

        case 'network-request-failed':
          message =
              'Network error. Please check your internet connection.';
          break;

        default:
          message =
              'Registration failed. Please try again. (${e.code})';
      }

      setState(() {
        isLoading = false;
        errorMessage = message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Could not complete registration. '
            'Check your connection and try again.';
      });
    }
  }

  // --------------------------------------------------
  // RESEND VERIFICATION EMAIL
  // --------------------------------------------------

  Future<void> resendVerificationEmail() async {
    final String email =
        emailController.text.trim().toLowerCase();

    final String password = passwordController.text;

    if (!isValidCollegeEmail(email)) {
      setState(() {
        clearMessages();
        errorMessage =
            'Enter your registered college email first.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        clearMessages();
        errorMessage =
            'Enter your password to resend the verification email.';
      });
      return;
    }

    setState(() {
      clearMessages();
      isLoading = true;
    });

    try {
      final UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
        );
      }

      await user.reload();
      user = _auth.currentUser;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
        );
      }

      if (user.emailVerified) {
        await _auth.signOut();

        if (!mounted) return;

        setState(() {
          isLoading = false;
          infoMessage =
              'Your email is already verified. '
              'Please sign in normally.';
        });

        return;
      }

      await user.sendEmailVerification();
      await _auth.signOut();

      if (!mounted) return;

      setState(() {
        isLoading = false;
        infoMessage =
            'A new verification email has been sent. '
            'Check your inbox and spam folder.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Could not resend verification email. '
            'Check your email and password. (${e.code})';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Something went wrong. Please try again.';
      });
    }
  }

  // --------------------------------------------------
  // FORGOT PASSWORD
  // --------------------------------------------------

  Future<void> forgotPassword() async {
    final String email =
        emailController.text.trim().toLowerCase();

    if (!isValidCollegeEmail(email)) {
      setState(() {
        clearMessages();
        errorMessage =
            'Enter your registered college email first.';
      });
      return;
    }

    setState(() {
      clearMessages();
      isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
        infoMessage =
            'If an account exists for this address, '
            'a password-reset email will be sent. '
            'Check your inbox and spam folder.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message =
          'Could not request a password reset. Please try again.';

      if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        message =
            'Too many requests. Please wait before trying again.';
      } else if (e.code == 'network-request-failed') {
        message =
            'Network error. Please check your internet connection.';
      }

      setState(() {
        isLoading = false;
        errorMessage = message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Something went wrong. Please try again.';
      });
    }
  }

  // --------------------------------------------------
  // SWITCH LOGIN / REGISTRATION
  // --------------------------------------------------

  void toggleMode() {
    setState(() {
      isRegisterMode = !isRegisterMode;
      clearMessages();
      passwordController.clear();
      confirmPasswordController.clear();
    });
  }

  // --------------------------------------------------
  // DISPOSE CONTROLLERS
  // --------------------------------------------------

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // REUSABLE TEXT FIELD
  // --------------------------------------------------

  InputDecoration fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF00897B),
      ),
      suffixIcon: suffixIcon,
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF00897B),
          width: 2,
        ),
      ),
    );
  }

  // --------------------------------------------------
  // BUILD SCREEN
  // --------------------------------------------------

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
              const SizedBox(height: 20),

              // Logo
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(45),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    size: 50,
                    color: Color(0xFF00897B),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // Heading
              Center(
                child: Text(
                  isRegisterMode
                      ? 'Create Your Account'
                      : 'Welcome to CampusRide',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Center(
                child: Text(
                  isRegisterMode
                      ? 'Join your campus ride-sharing community.'
                      : 'Connect with students travelling your way.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 35),

              // Email
              const Text(
                'VIT-AP Student Email',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !isLoading,
                decoration: fieldDecoration(
                  hint: 'student.regno@vitapstudent.ac.in',
                  icon: Icons.email_outlined,
                ),
                onChanged: (_) {
                  if (errorMessage != null ||
                      infoMessage != null) {
                    setState(() {
                      clearMessages();
                    });
                  }
                },
              ),

              const SizedBox(height: 22),

              // Password
              const Text(
                'Password',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                enabled: !isLoading,
                decoration: fieldDecoration(
                  hint: 'Enter your password',
                  icon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),

              // Confirm password
              if (isRegisterMode) ...[
                const SizedBox(height: 22),

                const Text(
                  'Confirm Password',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  enabled: !isLoading,
                  decoration: fieldDecoration(
                    hint: 'Re-enter your password',
                    icon: Icons.lock_reset_outlined,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscureConfirmPassword =
                              !obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ],

              // Forgot password
              if (!isRegisterMode) ...[
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed:
                        isLoading ? null : forgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF00897B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              // Error message
              if (errorMessage != null) ...[
                const SizedBox(height: 12),

                _buildMessageBox(
                  message: errorMessage!,
                  isError: true,
                ),
              ],

              // Information message
              if (infoMessage != null) ...[
                const SizedBox(height: 12),

                _buildMessageBox(
                  message: infoMessage!,
                  isError: false,
                ),
              ],

              const SizedBox(height: 25),

              // Main action button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : (isRegisterMode ? register : login),
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isRegisterMode
                              ? Icons.person_add_alt_1
                              : Icons.login,
                        ),
                  label: Text(
                    isLoading
                        ? 'Please wait...'
                        : (isRegisterMode
                            ? 'Create Account'
                            : 'Login'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        const Color(0xFF80CBC4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Switch login / registration
              Center(
                child: TextButton(
                  onPressed: isLoading ? null : toggleMode,
                  child: Text(
                    isRegisterMode
                        ? 'Already have an account? Login'
                        : "Don't have an account? Create Account",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF00897B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Resend verification email
              if (!isRegisterMode) ...[
                const SizedBox(height: 4),

                Center(
                  child: TextButton.icon(
                    onPressed: isLoading
                        ? null
                        : resendVerificationEmail,
                    icon: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 18,
                    ),
                    label: const Text(
                      'Resend Verification Email',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00897B),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // College email information
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: Color(0xFF00897B),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Use your @vitapstudent.ac.in email. '
                        'You must verify your email address '
                        'before accessing CampusRide.',
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

  // --------------------------------------------------
  // MESSAGE BOX
  // --------------------------------------------------

  Widget _buildMessageBox({
    required String message,
    required bool isError,
  }) {
    final Color backgroundColor =
        isError ? Colors.red.shade50 : Colors.green.shade50;

    final Color foregroundColor =
        isError ? Colors.red.shade800 : Colors.green.shade800;

    final Color borderColor =
        isError ? Colors.red.shade200 : Colors.green.shade200;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline
                : Icons.info_outline,
            color: foregroundColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}