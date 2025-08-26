import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/providers/settings_provider.dart';
import 'package:ride_share_app/models/settings_model.dart';
import 'package:ride_share_app/widgets/custom_button.dart';
import 'package:ride_share_app/widgets/custom_textfield.dart';
import 'package:ride_share_app/widgets/loading_indicator.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commissionController = TextEditingController();
  final _bookingTimeLimitHoursController = TextEditingController();
  final _cancellationTimeLimitHoursPassengerController = TextEditingController();
  final _cancellationTimeLimitHoursDriverController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    if (settingsProvider.settings == null) {
      await settingsProvider.fetchSettings();
    }

    if (mounted) {
      final settings = settingsProvider.settings;
      if (settings != null) {
        _commissionController.text = (settings.commissionRate * 100).toStringAsFixed(2);
        _bookingTimeLimitHoursController.text = settings.bookingTimeLimitHours.toString();
        _cancellationTimeLimitHoursPassengerController.text = settings.cancellationTimeLimitHoursPassenger.toString();
        _cancellationTimeLimitHoursDriverController.text = settings.cancellationTimeLimitHoursDriver.toString();
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

      try {
        // Ensure settings are not null before trying to access the ID
        if (settingsProvider.settings == null) {
          throw Exception("Settings have not been loaded yet.");
        }

        final newSettings = Settings(
          id: settingsProvider.settings!.id,
          commissionRate: double.parse(_commissionController.text.trim()) / 100,
          bookingTimeLimitHours: int.parse(_bookingTimeLimitHoursController.text.trim()),
          cancellationTimeLimitHoursPassenger: int.parse(_cancellationTimeLimitHoursPassengerController.text.trim()),
          cancellationTimeLimitHoursDriver: int.parse(_cancellationTimeLimitHoursDriverController.text.trim()),
        );

        await settingsProvider.updateSettings(newSettings);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: AppColors.secondaryColor)
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: AppColors.errorColor)
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
  void dispose() {
    _commissionController.dispose();
    _bookingTimeLimitHoursController.dispose();
    _cancellationTimeLimitHoursPassengerController.dispose();
    _cancellationTimeLimitHoursDriverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commission Rate (%)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _commissionController,
                        labelText: 'e.g., 15 for 15%',
                        keyboardType: TextInputType.number,
                        validator: (v) => (double.tryParse(v!) == null || double.parse(v) < 0 || double.parse(v) > 100) ? 'Enter a % between 0-100' : null,
                      ),
                      const SizedBox(height: 20),

                      Text('Booking Time Limit (Hours)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _bookingTimeLimitHoursController,
                        labelText: 'e.g., 1 hour before departure',
                        keyboardType: TextInputType.number,
                        validator: (v) => (int.tryParse(v!) == null || int.parse(v) < 0) ? 'Enter a valid number of hours' : null,
                      ),
                      const SizedBox(height: 20),

                      Text('Passenger Cancellation Limit (Hours)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _cancellationTimeLimitHoursPassengerController,
                        labelText: 'e.g., 2 hours before departure',
                        keyboardType: TextInputType.number,
                        validator: (v) => (int.tryParse(v!) == null || int.parse(v) < 0) ? 'Enter a valid number of hours' : null,
                      ),
                      const SizedBox(height: 20),

                      Text('Driver Cancellation Limit (Hours)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _cancellationTimeLimitHoursDriverController,
                        labelText: 'e.g., 4 hours before departure',
                        keyboardType: TextInputType.number,
                        validator: (v) => (int.tryParse(v!) == null || int.parse(v) < 0) ? 'Enter a valid number of hours' : null,
                      ),
                      const SizedBox(height: 24),

                      CustomButton(
                        text: 'Save Settings',
                        onPressed: _saveSettings,
                        color: AppColors.primaryColor,
                      ),
                    ],
                  ),
                ),
              ),
          ),
    );
  }
}
