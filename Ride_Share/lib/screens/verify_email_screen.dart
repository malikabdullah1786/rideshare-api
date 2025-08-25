import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/providers/auth_provider.dart'; // Import AppAuthProvider
import 'package:ride_share_app/screens/home_screen.dart';
import 'package:ride_share_app/widgets/custom_button.dart';
import 'package:ride_share_app/widgets/loading_indicator.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  User? _user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Periodically check email verification status
    // In a real app, you might use a timer or Firebase's onAuthStateChanged listener
    // combined with a manual reload. For simplicity here, we'll rely on button click.
  }

  Future<void> _checkEmailVerification() async {
    final appAuthProvider = Provider.of<AppAuthProvider>(context, listen: false); // Use AppAuthProvider
    await appAuthProvider.checkEmailVerificationStatus();

    if (context.mounted) {
      if (appAuthProvider.appUser?.emailVerified == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully!'),
            backgroundColor: AppColors.secondaryColor,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(appAuthProvider.error ?? 'Email not yet verified. Please check your inbox.'),
            backgroundColor: AppColors.warningColor,
          ),
        );
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      setState(() => _isLoading = true);
      await _user?.sendEmailVerification();
      setState(() => _error = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent!')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: LoadingIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email, size: 80, color: AppColors.primaryColor),
              SizedBox(height: screenSize.height * 0.025),
              const Text(
                'Verify Your Email',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: screenSize.height * 0.025),
              Text(
                'We sent a verification email to ${_user?.email}. Please check your inbox and spam folder.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              SizedBox(height: screenSize.height * 0.04),
              CustomButton(
                text: 'Resend Verification Email',
                onPressed: _resendVerificationEmail,
                color: AppColors.primaryColor,
              ),
              SizedBox(height: screenSize.height * 0.02),
              CustomButton(
                text: 'I\'ve Verified My Email',
                onPressed: _checkEmailVerification,
                color: AppColors.secondaryColor,
              ),
              if (_error != null) ...[
                SizedBox(height: screenSize.height * 0.025),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.errorColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}