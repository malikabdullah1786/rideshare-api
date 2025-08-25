import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/models/user_model.dart';
import 'package:ride_share_app/providers/auth_provider.dart'; // Import AppAuthProvider
import 'package:ride_share_app/screens/driver/driver_home.dart';
import 'package:ride_share_app/screens/rider/rider_home.dart';
import 'package:ride_share_app/screens/verify_email_screen.dart';
// Removed: import 'package:ride_share_app/screens/complete_profile_screen.dart'; // No longer needed if not forcing profile completion
import 'package:ride_share_app/widgets/custom_button.dart'; // Still needed for other buttons if any
import 'package:ride_share_app/widgets/loading_indicator.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appAuthProvider = Provider.of<AppAuthProvider>(context);
    final AppUser? currentUser = appAuthProvider.appUser;

    if (appAuthProvider.isLoading) {
      return const Scaffold(
        body: Center(child: LoadingIndicator()),
      );
    }

    if (currentUser == null) {
      // This case should ideally be handled by StreamBuilder in main.dart
      // and redirect to AuthScreen. But as a fallback:
      return const Scaffold(
        body: Center(child: Text('User data not loaded. Please log in again.')),
      );
    }

    // Check email verification status first
    // This step is crucial for security and often required.
    if (!currentUser.emailVerified) {
      return const VerifyEmailScreen();
    }

    // Removed the profileCompleted check:
    // if (!currentUser.profileCompleted) {
    //   return CompleteProfileScreen();
    // }

    // Route to appropriate home screen based on user type directly after email verification
    return currentUser.userType == 'driver'
        ? const DriverHomeScreen()
        : const RiderHomeScreen();
  }
}
