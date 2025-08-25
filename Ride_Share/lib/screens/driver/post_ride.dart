import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/providers/auth_provider.dart';
import 'package:ride_share_app/widgets/custom_button.dart';
import 'package:ride_share_app/widgets/custom_textfield.dart';
import 'package:ride_share_app/widgets/loading_indicator.dart';

class PostRideScreen extends StatefulWidget {
  const PostRideScreen({super.key});

  @override
  State<PostRideScreen> createState() => _PostRideScreenState();
}

class _PostRideScreenState extends State<PostRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _priceController = TextEditingController();
  final _seatsController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isLoading = false;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _priceController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppColors.textColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppColors.textColor,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _postRide() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both date and time for the ride.'),
            backgroundColor: AppColors.errorColor,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
        final databaseService = authProvider.databaseService;

        // Combine date and time into a single DateTime object (local time)
        // This DateTime object will implicitly carry the device's local timezone information.
        final DateTime localDepartureDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );

        // Convert to ISO 8601 string. When called on a non-UTC DateTime,
        // it automatically includes the timezone offset (e.g., "2025-07-15T10:00:00.000+05:00" for PKT).
        final String departureTimeString = localDepartureDateTime.toIso8601String();

        // --- DEBUG PRINT START ---
        print('PostRideScreen: Local Departure DateTime: $localDepartureDateTime (isUtc: ${localDepartureDateTime.isUtc})');
        print('PostRideScreen: TimeZone Name: ${localDepartureDateTime.timeZoneName}, TimeZone Offset: ${localDepartureDateTime.timeZoneOffset}');
        print('PostRideScreen: Sending ISO 8601 string (with local offset) to backend: $departureTimeString');
        // --- DEBUG PRINT END ---

        final rideData = {
          'from': _fromController.text.trim(),
          'to': _toController.text.trim(),
          'price': int.parse(_priceController.text.trim()),
          'seats': int.parse(_seatsController.text.trim()),
          'departureTime': departureTimeString,
        };

        await databaseService.postRide(rideData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ride posted successfully!'),
              backgroundColor: AppColors.secondaryColor,
            ),
          );
          Navigator.of(context).pop(); // Go back to driver dashboard
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to post ride: $e'),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post a New Ride'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                controller: _fromController,
                labelText: 'Departure Location',
                validator: (value) => value!.isEmpty ? 'Departure location is required.' : null,
              ),
              const SizedBox(height: 15),
              CustomTextField(
                controller: _toController,
                labelText: 'Destination',
                validator: (value) => value!.isEmpty ? 'Destination is required.' : null,
              ),
              const SizedBox(height: 15),
              CustomTextField(
                controller: _priceController,
                labelText: 'Price per Seat (PKR)',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Price is required.';
                  if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Please enter a valid price.';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              CustomTextField(
                controller: _seatsController,
                labelText: 'Total Seats Offered',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Number of seats is required.';
                  if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Please enter a valid number of seats.';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: _selectedDate == null
                          ? 'Select Date'
                          : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                      onPressed: () => _selectDate(context),
                      color: AppColors.secondaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomButton(
                      text: _selectedTime == null
                          ? 'Select Time'
                          : _selectedTime!.format(context),
                      onPressed: () => _selectTime(context),
                      color: AppColors.secondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              CustomButton(
                text: 'Post Ride',
                onPressed: _postRide,
                color: AppColors.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
