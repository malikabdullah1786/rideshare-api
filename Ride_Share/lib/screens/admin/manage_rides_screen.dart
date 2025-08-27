import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ride_share_app/models/ride_model.dart';
import 'package:ride_share_app/providers/auth_provider.dart';
import 'package:ride_share_app/widgets/loading_indicator.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/widgets/custom_textfield.dart';

class ManageRidesScreen extends StatefulWidget {
  const ManageRidesScreen({super.key});

  @override
  State<ManageRidesScreen> createState() => _ManageRidesScreenState();
}

class _ManageRidesScreenState extends State<ManageRidesScreen> {
  late Future<List<Ride>> _ridesFuture;

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  void _loadRides() {
    final dbService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
    setState(() {
      _ridesFuture = dbService.getAllRidesForAdmin();
    });
  }

  Future<void> _cancelRide(String rideId) async {
    final reason = await _showCancelationDialog();
    if (reason == null || reason.isEmpty) return;

    final dbService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
    try {
      await dbService.adminCancelRide(rideId, reason);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride cancelled successfully.'), backgroundColor: AppColors.secondaryColor),
      );
      _loadRides(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel ride: $e'), backgroundColor: AppColors.errorColor),
      );
    }
  }

  Future<String?> _showCancelationDialog() {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>(); // Add a form key
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: Form(
          key: formKey,
          child: CustomTextField(
            controller: controller,
            labelText: 'Reason for cancellation',
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Reason cannot be empty.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Confirm Cancellation'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorColor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage All Rides'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: FutureBuilder<List<Ride>>(
        future: _ridesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No rides found.'));
          }

          final rides = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _loadRides(),
            child: ListView.builder(
              itemCount: rides.length,
              itemBuilder: (context, index) {
                final ride = rides[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 2,
                  child: ListTile(
                    title: Text('${ride.from} to ${ride.to}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Driver: ${ride.driverName ?? 'N/A'}'),
                        Text('Departure: ${DateFormat('MMM dd, yyyy - hh:mm a').format(ride.departureTime)}'),
                        Text('Price per Seat: PKR ${ride.price}'),
                        if (ride.suggestedPrice != null)
                          Text('Suggested Fare: PKR ${ride.suggestedPrice!.toStringAsFixed(2)}'),
                        const SizedBox(height: 4),
                        Text('Status: ${ride.status}', style: TextStyle(fontWeight: FontWeight.bold, color: ride.status == 'cancelled' ? AppColors.errorColor : AppColors.primaryColor)),
                      ],
                    ),
                    trailing: ride.status == 'active'
                        ? IconButton(
                            icon: const Icon(Icons.cancel, color: AppColors.errorColor),
                            onPressed: () => _cancelRide(ride.id!),
                          )
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
