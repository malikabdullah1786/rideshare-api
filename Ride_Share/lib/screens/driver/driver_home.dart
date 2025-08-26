import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/providers/auth_provider.dart';
import 'package:ride_share_app/screens/driver/post_ride.dart';
import 'package:ride_share_app/widgets/custom_button.dart';
import 'package:ride_share_app/widgets/loading_indicator.dart';
import 'package:ride_share_app/widgets/custom_textfield.dart';
import 'package:ride_share_app/models/ride_model.dart';
import 'package:intl/intl.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isLoadingRides = false;
  List<Ride> _postedRides = [];
  double _totalEarnings = 0.0;
  int _completedRideCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDriverDashboardData();
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        final dbService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
        final newImageUrl = await dbService.uploadProfilePicture(image);
        Provider.of<AppAuthProvider>(context, listen: false).updateUserProfilePicture(newImageUrl);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      }
    }
  }

  Future<void> _loadDriverDashboardData() async {
    setState(() {
      _isLoadingRides = true;
      _postedRides = [];
      _totalEarnings = 0.0;
      _completedRideCount = 0;
    });
    try {
      final databaseService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      final List<dynamic> rideMaps = await databaseService.getMyPostedRides();
      if(mounted) setState(() => _postedRides = rideMaps.map((map) => Ride.fromMap(map)).toList());
      final Map<String, dynamic> earningsData = await databaseService.getDriverEarnings();
      if(mounted) setState(() {
        _totalEarnings = (earningsData['totalEarnings'] as num).toDouble();
        _completedRideCount = earningsData['completedRideCount'] ?? 0;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load dashboard data: $e'), backgroundColor: AppColors.errorColor));
    } finally {
      if(mounted) setState(() => _isLoadingRides = false);
    }
  }

  Future<void> _showCancelRideDialog(String rideId) async {
    final TextEditingController reasonController = TextEditingController();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Ride'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please provide a reason for cancelling this ride:'),
                const SizedBox(height: 10),
                CustomTextField(controller: reasonController, labelText: 'Cancellation Reason', maxLines: 3),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Back'),
              onPressed: () {
                reasonController.dispose();
                Navigator.of(dialogContext).pop();
              },
            ),
            CustomButton(
              text: 'Confirm Cancel',
              onPressed: () async {
                final String reason = reasonController.text.trim();
                reasonController.dispose();
                Navigator.of(dialogContext).pop();
                await _cancelRide(rideId, reason.isEmpty ? 'No reason provided' : reason);
              },
              color: AppColors.errorColor,
              width: 150,
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAdminCancelRideDialog(String rideId) async {
    final TextEditingController reasonController = TextEditingController();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Admin: Cancel Ride'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('You are cancelling this ride as an admin. Please provide a reason:'),
                const SizedBox(height: 10),
                CustomTextField(controller: reasonController, labelText: 'Admin Cancellation Reason', maxLines: 3),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Back'),
              onPressed: () {
                reasonController.dispose();
                Navigator.of(dialogContext).pop();
              },
            ),
            CustomButton(
              text: 'Confirm Admin Cancel',
              onPressed: () async {
                final String reason = reasonController.text.trim();
                if(reason.isEmpty){
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Admin reason cannot be empty.')));
                  return;
                }
                reasonController.dispose();
                Navigator.of(dialogContext).pop();
                await _adminCancelRide(rideId, reason);
              },
              color: AppColors.errorColor,
              width: 200,
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelRide(String rideId, String? reason) async {
    setState(() => _isLoadingRides = true);
    try {
      final databaseService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      await databaseService.cancelRide(rideId, reason);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride cancelled successfully!')));
      _loadDriverDashboardData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel ride: $e')));
    } finally {
      if(mounted) setState(() => _isLoadingRides = false);
    }
  }

  Future<void> _adminCancelRide(String rideId, String reason) async {
    setState(() => _isLoadingRides = true);
    try {
      final databaseService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      await databaseService.adminCancelRide(rideId, reason);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride cancelled by admin successfully!')));
      _loadDriverDashboardData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel ride as admin: $e')));
    } finally {
      if(mounted) setState(() => _isLoadingRides = false);
    }
  }

  Future<void> _completeRide(String rideId) async {
    setState(() => _isLoadingRides = true);
    try {
      final databaseService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      await databaseService.completeRide(rideId);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride marked as completed!')));
      _loadDriverDashboardData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to complete ride: $e')));
    } finally {
      if(mounted) setState(() => _isLoadingRides = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appAuthProvider = Provider.of<AppAuthProvider>(context);
    final screenSize = MediaQuery.of(context).size;
    final bool isAdmin = appAuthProvider.appUser?.userType == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'Admin Dashboard' : 'Driver Dashboard'),
        backgroundColor: AppColors.primaryColor,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDriverDashboardData),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async => await appAuthProvider.logout()),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(appAuthProvider.appUser?.profilePictureUrl ?? ''),
                  child: appAuthProvider.appUser?.profilePictureUrl == null || appAuthProvider.appUser!.profilePictureUrl!.isEmpty ? const Icon(Icons.person, size: 30) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome, ${isAdmin ? "Admin" : "Driver"} ${appAuthProvider.appUser?.name ?? ''}!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      TextButton(onPressed: _pickAndUploadImage, child: const Text('Change Profile Picture')),
                    ],
                  ),
                ),
              ],
            ),
            if(!isAdmin) ...[
              SizedBox(height: screenSize.height * 0.02),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('Total Earnings', style: TextStyle(fontSize: 16, color: AppColors.hintColor), textAlign: TextAlign.center),
                            Text('PKR ${_totalEarnings.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.secondaryColor)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('Completed Rides', style: TextStyle(fontSize: 16, color: AppColors.hintColor), textAlign: TextAlign.center),
                            Text('$_completedRideCount', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.03),
              CustomButton(
                text: 'Post a Ride',
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const PostRideScreen()));
                  _loadDriverDashboardData();
                },
                color: AppColors.primaryColor,
              ),
            ],
            SizedBox(height: screenSize.height * 0.02),
            Text(isAdmin ? 'All Posted Rides:' : 'Your Posted Rides History:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: screenSize.height * 0.01),
            _isLoadingRides
                ? const Center(child: LoadingIndicator())
                : Expanded(
                    child: _postedRides.isEmpty
                        ? Center(child: Text(isAdmin ? 'No rides posted by anyone.' : 'No rides posted yet. Post your first ride!', style: TextStyle(color: AppColors.hintColor)))
                        : ListView.builder(
                            itemCount: _postedRides.length,
                            itemBuilder: (context, index) {
                              final ride = _postedRides[index];
                              final bool isPastDeparture = ride.departureTime.isBefore(DateTime.now());
                              final bool isCompleted = ride.status == 'completed';
                              final bool isCancelled = ride.status == 'cancelled';
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${ride.from} to ${ride.to}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text('Departure: ${DateFormat('MMM dd, hh:mm a').format(ride.departureTime)}'),
                                      Text('Price: PKR ${ride.price}'),
                                      Text('Seats: ${ride.seatsAvailable}/${ride.seats} available'),
                                      Text('Status: ${ride.status.toUpperCase()}'),
                                      if (isCancelled && ride.cancellationReason != null && ride.cancellationReason!.isNotEmpty)
                                        Text('Reason: ${ride.cancellationReason}', style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.hintColor)),
                                      const SizedBox(height: 10),
                                      if (ride.passengers.isNotEmpty)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Booked Passengers (${ride.passengers.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ...ride.passengers.map((passenger) {
                                              return Padding(
                                                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(' - Name: ${passenger.userName ?? 'N/A'} (Seats: ${passenger.bookedSeats})'),
                                                    Text('   Email: ${passenger.userEmail ?? 'N/A'}'),
                                                    Text('   Phone: ${passenger.contactPhone}'),
                                                    Text('   Pickup: ${passenger.pickupAddress}'),
                                                    Text('   Drop-off: ${passenger.dropoffAddress}'),
                                                    Text('   Booking Status: ${passenger.status.toUpperCase()}'),
                                                    if (passenger.status == 'cancelled_by_rider' && passenger.cancellationReason != null && passenger.cancellationReason!.isNotEmpty)
                                                      Text('   Rider Reason: ${passenger.cancellationReason}', style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.hintColor)),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ),
                                      const SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          if (!isAdmin && !isCompleted && !isCancelled && isPastDeparture) Expanded(child: CustomButton(text: 'Mark Completed', onPressed: () => _completeRide(ride.id), color: AppColors.secondaryColor)),
                                          if (!isAdmin && !isCompleted && !isCancelled && !isPastDeparture) const SizedBox(width: 10),
                                          if (!isAdmin && !isCompleted && !isCancelled && !isPastDeparture) Expanded(child: CustomButton(text: 'Cancel Ride', onPressed: () => _showCancelRideDialog(ride.id), color: AppColors.errorColor)),
                                          if (isAdmin && !isCompleted && !isCancelled) Expanded(child: CustomButton(text: 'Cancel Ride (Admin)', onPressed: () => _showAdminCancelRideDialog(ride.id), color: AppColors.errorColor)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ],
        ),
      ),
    );
  }
}
