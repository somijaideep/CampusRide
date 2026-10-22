import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentData {
  static String name = 'Student';
  static String registrationNumber = '';
  static String email = '';
  static String phone = '';

  static String? _loadedUid;

  /// Load the currently authenticated student's details.
  static Future<void> loadStudentData() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in to view your profile.');
    }

    final String userEmail =
        (user.email ?? '').trim().toLowerCase();

    email = userEmail;
    name = _extractName(userEmail);
    registrationNumber = _extractRegistrationNumber(userEmail);
    phone = '';

    _loadedUid = user.uid;

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance
            .collection('students')
            .doc(user.uid)
            .get();

    // Don't apply data if the logged-in account changed during loading.
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      return;
    }

    final Map<String, dynamic>? data = snapshot.data();

    if (data != null) {
      phone = (data['phone'] ?? '').toString();
    }
  }

  /// Extract the first name from:
  /// jaideep.24bcs7001@vitapstudent.ac.in
  static String _extractName(String userEmail) {
    final String username = userEmail.split('@').first;
    final int dotIndex = username.indexOf('.');

    if (dotIndex <= 0) {
      return username.isEmpty ? 'Student' : _capitalize(username);
    }

    return _capitalize(username.substring(0, dotIndex));
  }

  /// Extract the registration number from the email username.
  static String _extractRegistrationNumber(String userEmail) {
    final String username = userEmail.split('@').first;
    final List<String> parts = username.split('.');

    if (parts.length < 2 || parts[1].trim().isEmpty) {
      return '';
    }

    return parts[1].toUpperCase();
  }

  static String _capitalize(String value) {
    if (value.isEmpty) {
      return 'Student';
    }

    return value[0].toUpperCase() + value.substring(1);
  }

  /// Save the phone number under the authenticated student's UID.
  static Future<void> savePhone(String phoneNumber) async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception(
        'Please log in to update your phone number.',
      );
    }

    final String normalizedPhone = phoneNumber.trim();

    if (!RegExp(r'^\+?[0-9]{10,13}$')
        .hasMatch(normalizedPhone)) {
      throw Exception(
        'Enter a valid phone number containing 10–13 digits, '
        'optionally starting with +.',
      );
    }

    await FirebaseFirestore.instance
        .collection('students')
        .doc(user.uid)
        .set(
      {
        'phone': normalizedPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (FirebaseAuth.instance.currentUser?.uid == user.uid) {
      phone = normalizedPhone;
      _loadedUid = user.uid;
    }
  }

  /// Reload details when the authenticated account changes.
  static Future<void> ensureLoaded() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('Please log in to view your profile.');
    }

    final String currentEmail =
        (user.email ?? '').trim().toLowerCase();

    if (_loadedUid != user.uid || email != currentEmail) {
      await loadStudentData();
    }
  }
}
