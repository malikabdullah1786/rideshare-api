import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ride_share_app/models/user_model.dart';
import 'package:ride_share_app/services/auth_service.dart';
import 'package:ride_share_app/services/database_service.dart';

class AppAuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  AppUser? _appUser;
  bool _isLoading = false;
  String? _error;

  AppUser? get appUser => _appUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DatabaseService get databaseService => _databaseService;

  AppAuthProvider() {
    _authService.firebaseAuth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser != null) {
        await loadExtendedUserData(firebaseUser.uid);
      } else {
        _appUser = null;
        _databaseService.setAuthToken(null);
        notifyListeners();
      }
    });
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void updateUserProfilePicture(String newImageUrl) {
    if (_appUser != null) {
      _appUser = _appUser!.copyWith(profilePictureUrl: newImageUrl);
      notifyListeners();
    }
  }

  Future<void> loadExtendedUserData(String firebaseUid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final idToken = await firebaseUser.getIdToken();
        _databaseService.setAuthToken(idToken);
      } else {
        _databaseService.setAuthToken(null);
      }

      final userDataMap = await _databaseService.getUserProfile(firebaseUid);
      if (userDataMap != null) {
        _appUser = AppUser.fromMap(userDataMap);
      } else {
        if (firebaseUser != null) {
          _appUser = AppUser(
            id: firebaseUser.uid, // Use firebaseUid as a temporary ID
            firebaseUid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            name: firebaseUser.displayName ?? 'New User',
            cnic: '',
            phone: firebaseUser.phoneNumber ?? '', // Firebase phone number might be null initially
            address: '',
            emergencyContact: '',
            gender: '',
            age: 0,
            userType: 'rider',
            emailVerified: firebaseUser.emailVerified,
            profileCompleted: false,
            createdAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      _setError("Failed to load user profile: $e");
      _appUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateAppUser(AppUser user) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final Map<String, dynamic> userMap = user.toMap();
      userMap['phone'] = _formatPhoneNumberToE164(user.phone ?? '');
      // Ensure required fields are not null/empty before updating
      userMap['emergencyContact'] = userMap['emergencyContact']?.isNotEmpty == true ? userMap['emergencyContact'] : 'N/A';
      userMap['gender'] = userMap['gender']?.isNotEmpty == true ? userMap['gender'] : 'Unknown';
      userMap['age'] = (userMap['age'] is int && userMap['age'] > 0) ? userMap['age'] : 18;

      await _databaseService.updateUserProfile(userMap);
      _appUser = user;
      _setError("Profile updated successfully!");
    } catch (e) {
      _setError("Failed to update profile: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _formatPhoneNumberToE164(String rawPhoneNumber) {
    String e164PhoneNumber = rawPhoneNumber.trim();
    e164PhoneNumber = e164PhoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (e164PhoneNumber.isEmpty) {
      return '';
    }

    if (e164PhoneNumber.startsWith('0')) {
      e164PhoneNumber = '+92' + e164PhoneNumber.substring(1);
    } else if (!e164PhoneNumber.startsWith('+')) {
      e164PhoneNumber = '+92' + e164PhoneNumber;
    }
    return e164PhoneNumber;
  }

  Future<void> registerUser({
    required String email,
    required String password,
    required String name,
    required String cnic,
    required String phone,
    required String address,
    required String emergencyContact, // Ensure this is provided by UI
    required String gender,           // Ensure this is provided by UI
    required int age,                 // Ensure this is provided by UI
    required String userType,
    String? carModel,
    String? carRegistration,
    int? seatsAvailable,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final String formattedPhone = _formatPhoneNumberToE164(phone);
      print('AuthProvider: Original phone: $phone, Formatted E.164 phone: $formattedPhone');

      final UserCredential? userCredential = await _authService.signUpWithEmail(email, password);

      if (userCredential != null && userCredential.user != null) {
        final firebaseUser = userCredential.user!;
        await firebaseUser.sendEmailVerification();

        // Create a temporary map to build the user data, ensuring defaults for required fields
        final Map<String, dynamic> newUserMap = {
          'firebaseUid': firebaseUser.uid,
          'email': email,
          'name': name,
          'cnic': cnic,
          'phone': formattedPhone,
          'address': address,
          // Explicitly check and provide defaults for required fields
          'emergencyContact': emergencyContact.isNotEmpty ? emergencyContact : 'N/A',
          'gender': gender.isNotEmpty ? gender : 'Unknown',
          'age': age > 0 ? age : 18, // Ensure age is positive
          'userType': userType,
          'emailVerified': firebaseUser.emailVerified,
          'profileCompleted': true, // Mark as true since we're creating the full profile
          'createdAt': DateTime.now().toIso8601String(), // Ensure ISO string for backend
        };

        // Add optional fields if they are not null
        if (carModel != null) newUserMap['carModel'] = carModel;
        if (carRegistration != null) newUserMap['carRegistration'] = carRegistration;
        if (seatsAvailable != null) newUserMap['seatsAvailable'] = seatsAvailable;

        newUserMap['password'] = password; // Send password for hashing on backend if needed

        print('AuthProvider: Sending to backend: $newUserMap'); // DEBUG: Print the map being sent

        final backendResponse = await _databaseService.registerUserProfile(newUserMap);

        if (backendResponse != null && backendResponse['token'] != null) {
          _databaseService.setAuthToken(backendResponse['token']);
          _appUser = AppUser.fromMap(backendResponse['user']);
          _setError("Registration successful! Please verify your email.");
        } else {
          _setError(backendResponse?['message'] ?? "Backend registration failed.");
        }
      } else {
        _setError("Registration failed. No user created by Firebase Auth.");
      }
    } on FirebaseAuthException catch (e) {
      _setError(_authService.getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      _setError("An unexpected error occurred: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginUser(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final UserCredential? userCredential = await _authService.signInWithEmail(email, password);

      if (userCredential != null && userCredential.user != null) {
        final firebaseIdToken = await userCredential.user!.getIdToken();
        _databaseService.setAuthToken(firebaseIdToken);

        final backendResponse = await _databaseService.loginUser(email, password);

        if (backendResponse != null && backendResponse['token'] != null) {
          _databaseService.setAuthToken(backendResponse['token']);
        }

        await loadExtendedUserData(userCredential.user!.uid);

        _setError("Login successful!");
      } else {
        _setError("Login failed. Invalid credentials.");
      }
    } on FirebaseAuthException catch (e) {
      _setError(_authService.getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      _setError("An unexpected error occurred: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      _setError("Password reset link sent to $email. Check your inbox.");
    } on FirebaseAuthException catch (e) {
      _setError(_authService.getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      _setError("An unexpected error occurred: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signOut();
      _appUser = null;
      _databaseService.setAuthToken(null);
    } catch (e) {
      _setError("Logout failed: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkEmailVerificationStatus() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _setError("No logged in user to verify.");
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await firebaseUser.reload();
      final updatedFirebaseUser = FirebaseAuth.instance.currentUser;

      if (updatedFirebaseUser != null && updatedFirebaseUser.emailVerified) {
        final bool wasAlreadyVerifiedInApp = _appUser?.emailVerified ?? false;

        _appUser = _appUser?.copyWith(emailVerified: true, profileCompleted: true);

        if (_appUser != null && !wasAlreadyVerifiedInApp) {
          await _databaseService.updateUserProfile(_appUser!.toMap());
          notifyListeners(); // Notify listeners of the change in _appUser
        }

        _setError("Email verified successfully!");
      } else {
        _setError("Email not yet verified. Please check your inbox.");
      }
    } on FirebaseAuthException catch (e) {
      _setError(_authService.getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      _setError("Failed to check verification status: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
