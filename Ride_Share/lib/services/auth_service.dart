import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  FirebaseAuth get firebaseAuth => _firebaseAuth;

  // Get currently logged-in Firebase User
  User? get currentUser => _firebaseAuth.currentUser;

  // --- Email/Password Authentication ---

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    return await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    return await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // --- Password Reset ---
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  // --- Sign Out ---
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // --- Error Message Helper ---
  String getFirebaseAuthErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'email-already-in-use':
        return 'The email address is already in use by another account.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Enable them in Firebase Console.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'user-disabled':
        return 'The user account has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password provided for this user.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'An unknown Firebase error occurred: $errorCode';
    }
  }
}