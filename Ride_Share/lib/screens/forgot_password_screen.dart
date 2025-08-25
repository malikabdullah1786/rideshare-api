import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_validator/email_validator.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/providers/auth_provider.dart'; // Import AppAuthProvider
import 'package:ride_share_app/widgets/custom_button.dart';
import 'package:ride_share_app/widgets/custom_textfield.dart';
import 'package:ride_share_app/widgets/loading_indicator.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_formKey.currentState!.validate()) {
      final appAuthProvider = Provider.of<AppAuthProvider>(context, listen: false); // Use AppAuthProvider
      await appAuthProvider.sendPasswordResetEmail(_emailController.text.trim());

      if (context.mounted) {
        if (appAuthProvider.error != null &&
            !appAuthProvider.error!.contains("Password reset link sent")) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appAuthProvider.error!),
              backgroundColor: AppColors.errorColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appAuthProvider.error ?? 'Password reset link sent!'),
              backgroundColor: AppColors.secondaryColor,
            ),
          );
          Navigator.pop(context); // Go back to login screen
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
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: screenSize.height * 0.1),
              const Text(
                'Enter your email to receive a password reset link.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textColor),
              ),
              SizedBox(height: screenSize.height * 0.05),
              CustomTextField(
                controller: _emailController,
                labelText: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!EmailValidator.validate(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenSize.height * 0.05),
              if (appAuthProvider.error != null &&
                  !appAuthProvider.error!.contains("Password reset link sent"))
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Text(
                    appAuthProvider.error!,
                    style: const TextStyle(color: AppColors.errorColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              CustomButton(
                text: 'Send Reset Link',
                onPressed: _sendResetEmail,
                color: AppColors.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}