import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_validator/email_validator.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/providers/auth_provider.dart'; // Import AppAuthProvider
import 'package:ride_share_app/widgets/custom_button.dart';
import 'package:ride_share_app/widgets/custom_textfield.dart';
import 'package:ride_share_app/widgets/loading_indicator.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _ageController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carRegistrationController = TextEditingController();
  final _seatsAvailableController = TextEditingController();

  String _gender = 'Male';
  String _userType = 'rider'; // Default user type

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _emergencyContactController.dispose();
    _ageController.dispose();
    _carModelController.dispose();
    _carRegistrationController.dispose();
    _seatsAvailableController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      final appAuthProvider = Provider.of<AppAuthProvider>(context, listen: false); // Use AppAuthProvider

      int? age = int.tryParse(_ageController.text.trim());
      int? seats = int.tryParse(_seatsAvailableController.text.trim());

      await appAuthProvider.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        cnic: _cnicController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        emergencyContact: _emergencyContactController.text.trim(),
        gender: _gender,
        age: age ?? 0, // Provide default if parsing fails
        userType: _userType,
        carModel: _userType == 'driver' ? _carModelController.text.trim() : null,
        carRegistration: _userType == 'driver' ? _carRegistrationController.text.trim() : null,
        seatsAvailable: _userType == 'driver' ? seats : null,
      );

      // Show success/error message
      if (context.mounted) {
        if (appAuthProvider.error != null && !appAuthProvider.error!.contains("successful")) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appAuthProvider.error!),
              backgroundColor: AppColors.errorColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(appAuthProvider.error ?? 'Registration successful! Please verify your email.'),
              backgroundColor: AppColors.secondaryColor,
            ),
          );
          // Navigate back to AuthScreen to allow login or to VerifyEmailScreen
          Navigator.pop(context);
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
        title: const Text('Register'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _userType,
                items: const [
                  DropdownMenuItem(value: 'rider', child: Text('Passenger')),
                  DropdownMenuItem(value: 'driver', child: Text('Driver')),
                ],
                onChanged: (value) {
                  setState(() {
                    _userType = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'I am a',
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
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
              SizedBox(height: screenSize.height * 0.02),
              CustomTextField(
                controller: _passwordController,
                labelText: 'Password',
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenSize.height * 0.02),
              CustomTextField(
                controller: _nameController,
                labelText: 'Full Name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenSize.height * 0.02),
              CustomTextField(
                controller: _cnicController,
                labelText: 'CNIC (without dashes)',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your CNIC';
                  }
                  if (value.length != 13) {
                    return 'CNIC must be 13 digits';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenSize.height * 0.02),
              CustomTextField(
                controller: _phoneController,
                labelText: 'Phone Number (e.g., 923001234567)',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length < 11) {
                    return 'Invalid phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenSize.height * 0.02),
              CustomTextField(
                controller: _addressController,
                labelText: 'Address',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your address';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenSize.height * 0.02),
              CustomTextField(
                controller: _emergencyContactController,
                labelText: 'Emergency Contact Number',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter emergency contact';
                  }
                  if (value.length < 11) {
                    return 'Invalid phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: screenSize.height * 0.02),
              DropdownButtonFormField<String>(
                value: _gender,
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    _gender = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Gender',
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),
              CustomTextField(
                controller: _ageController,
                labelText: 'Age',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your age';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 1) {
                    return 'Please enter a valid age';
                  }
                  return null;
                },
              ),
              if (_userType == 'driver') ...[
                SizedBox(height: screenSize.height * 0.02),
                CustomTextField(
                  controller: _carModelController,
                  labelText: 'Car Model',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your car model';
                    }
                    return null;
                  },
                ),
                SizedBox(height: screenSize.height * 0.02),
                CustomTextField(
                  controller: _carRegistrationController,
                  labelText: 'Car Registration Number',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter registration number';
                    }
                    return null;
                  },
                ),
                SizedBox(height: screenSize.height * 0.02),
                CustomTextField(
                  controller: _seatsAvailableController,
                  labelText: 'Number of Seats Available',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter seat count';
                    }
                    if (int.tryParse(value) == null || int.parse(value) < 1) {
                      return 'At least 1 seat required';
                    }
                    return null;
                  },
                ),
              ],
              SizedBox(height: screenSize.height * 0.025),
              if (appAuthProvider.error != null)
                Text(
                  appAuthProvider.error!,
                  style: const TextStyle(color: AppColors.errorColor),
                  textAlign: TextAlign.center,
                ),
              SizedBox(height: screenSize.height * 0.025),
              CustomButton(
                text: 'Register',
                onPressed: _register,
                color: AppColors.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}