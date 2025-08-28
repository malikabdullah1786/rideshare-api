import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/providers/auth_provider.dart'; // Import AppAuthProvider
import 'package:ride_share_app/screens/forgot_password_screen.dart';
import 'package:ride_share_app/screens/register_screen.dart';
import 'package:ride_share_app/screens/verify_email_screen.dart'; // Import the verify email screen
import 'package:ride_share_app/widgets/custom_button.dart';
import 'package:ride_share_app/widgets/custom_textfield.dart';
import 'package:ride_share_app/widgets/loading_indicator.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loginFormKey.currentState!.validate()) {
      final appAuthProvider = Provider.of<AppAuthProvider>(context, listen: false); // Use AppAuthProvider
      await appAuthProvider.loginUser(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (context.mounted) {
        // After login attempt, check for user status
        final user = appAuthProvider.appUser;
        if (appAuthProvider.error == null && user != null) {
          // Login was successful, now check email verification
          if (!user.emailVerified) {
            // Navigate to the verification screen if email is not verified
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const VerifyEmailScreen()),
            );
          }
          // If email is verified, the StreamBuilder in main.dart will handle navigation to HomeScreen.
        } else if (appAuthProvider.error != null) {
          // If there was an error during login, show it.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appAuthProvider.error!),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appAuthProvider = Provider.of<AppAuthProvider>(context); // Use AppAuthProvider
    final screenSize = MediaQuery.of(context).size;

    if (appAuthProvider.isLoading) {
      return const Scaffold(
        body: Center(child: LoadingIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Ride Share App'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/logo.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: screenSize.height * 0.05),
            Image.asset(
              'assets/images/logo.png', // Ensure you have this image
              height: screenSize.height * 0.15,
            ),
            SizedBox(height: screenSize.height * 0.05),
            Text(
              'Login to your account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor,
              ),
            ),
            SizedBox(height: screenSize.height * 0.025),
            Form(
              key: _loginFormKey,
              child: Column(
                children: [
                  CustomTextField(
                    controller: _emailController,
                    labelText: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      // Basic email validation
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: screenSize.height * 0.02),
                  CustomTextField(
                    controller: _passwordController,
                    labelText: 'Password',
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: screenSize.height * 0.025),
            // Error message from AppAuthProvider
            if (appAuthProvider.error != null && !appAuthProvider.error!.contains("successful"))
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text(
                  appAuthProvider.error!,
                  style: const TextStyle(color: AppColors.errorColor),
                  textAlign: TextAlign.center,
                ),
              ),
            CustomButton(
              text: 'Login',
              onPressed: _login,
              color: AppColors.primaryColor,
            ),
            SizedBox(height: screenSize.height * 0.02),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen()),
                  );
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(color: AppColors.primaryColor),
                ),
              ),
            ),
            SizedBox(height: screenSize.height * 0.025),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Don\'t have an account?'),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text(
                    'Register Now',
                    style: TextStyle(color: AppColors.secondaryColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}