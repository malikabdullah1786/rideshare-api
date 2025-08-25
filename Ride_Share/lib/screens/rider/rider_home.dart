import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/providers/auth_provider.dart';
import 'package:ride_share_app/screens/rider/find_rides.dart';
import 'package:ride_share_app/screens/ride_tracking_screen.dart';
import 'package:ride_share_app/widgets/custom_button.dart';
import 'package:ride_share_app/widgets/custom_textfield.dart';
import 'package:ride_share_app/widgets/loading_indicator.dart';
import 'package:ride_share_app/models/ride_model.dart';
import 'package:collection/collection.dart'; // IMPORTANT: This provides firstWhereOrNull

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  bool _isLoadingBookedRides = false;
  List<Ride> _bookedRides = [];

  @override
  void initState() {
    super.initState();
    print('RiderHomeScreen: initState called.');
    _loadBookedRides();
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: $e')),
          );
        }
      }
    }
  }

  Future<void> _loadBookedRides() async {
    print('RiderHomeScreen: _loadBookedRides started.');
    setState(() {
      _isLoadingBookedRides = true;
      _bookedRides = [];
      print('RiderHomeScreen: _isLoadingBookedRides set to true, _bookedRides cleared.');
    });

    try {
      final appAuthProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final databaseService = appAuthProvider.databaseService;

      print('RiderHomeScreen: Calling getMyBookedRides from DatabaseService...');
      final List<dynamic> rideMaps = await databaseService.getMyBookedRides();
      print('RiderHomeScreen: Received ${rideMaps.length} ride maps from backend.');
      print('RiderHomeScreen: Raw rideMaps data: $rideMaps'); // Log raw data

      List<Ride> parsedRides = [];
      for (var map in rideMaps) {
        try {
          final ride = Ride.fromMap(map);
          parsedRides.add(ride);
          print('RiderHomeScreen: Successfully parsed ride: ${ride.id}');
        } catch (e, stacktrace) {
          print('RiderHomeScreen: ERROR parsing ride map: $map');
          print('RiderHomeScreen: Parsing error: $e');
          print('RiderHomeScreen: Parsing stacktrace: $stacktrace');
        }
      }

      setState(() {
        _bookedRides = parsedRides;
        print('RiderHomeScreen: _bookedRides updated with ${_bookedRides.length} parsed rides.');
      });

      print('--- _loadBookedRides Debug End (Success Path) ---');

    } catch (e, stacktrace) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load booked rides: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
      print('RiderHomeScreen: Error loading booked rides: $e');
      print('RiderHomeScreen: Stacktrace: $stacktrace');
      print('--- _loadBookedRides Debug End (Error Path) ---\n');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBookedRides = false;
          print('RiderHomeScreen: _isLoadingBookedRides set to false in finally block.');
        });
      }
    }
  }

  Future<void> _showCancelBookingDialog(String rideId) async {
    final TextEditingController reasonController = TextEditingController();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Booking'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please provide a reason for cancelling your booking:'),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: reasonController,
                  labelText: 'Cancellation Reason',
                  maxLines: 3,
                ),
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
                Navigator.of(dialogContext).pop(); // Dismiss dialog
                await _cancelBooking(rideId, reason.isEmpty ? 'No reason provided' : reason);
              },
              color: AppColors.errorColor,
              width: 150,
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelBooking(String rideId, String? reason) async {
    setState(() => _isLoadingBookedRides = true);
    try {
      final databaseService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      await databaseService.cancelBooking(rideId, reason);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride booking cancelled successfully!')),
        );
      }
      _loadBookedRides(); // Refresh booked rides
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel booking: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingBookedRides = false);
      }
    }
  }

  Future<void> _showRatingDialog(String rideId) async {
    int? selectedRating;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Rate Your Driver'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How would you rate your driver (1-5 stars)?'),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < (selectedRating ?? 0) ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedRating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            CustomButton(
              text: 'Submit Rating',
              onPressed: () async {
                if (selectedRating != null) {
                  Navigator.of(dialogContext).pop(); // Dismiss dialog
                  await _rateDriver(rideId, selectedRating!);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a rating.')),
                    );
                  }
                }
              },
              color: AppColors.primaryColor,
              width: 150,
            ),
          ],
        );
      },
    );
  }

  Future<void> _rateDriver(String rideId, int rating) async {
    setState(() => _isLoadingBookedRides = true);
    try {
      final databaseService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      await databaseService.rateDriver(rideId, rating);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver rated successfully!')),
        );
      }
      _loadBookedRides(); // Refresh booked rides to update status
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rate driver: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingBookedRides = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appAuthProvider = Provider.of<AppAuthProvider>(context);
    final screenSize = MediaQuery.of(context).size;
    print('RiderHomeScreen: build method called.');
    print('RiderHomeScreen: appAuthProvider.appUser is null: ${appAuthProvider.appUser == null}');
    print('RiderHomeScreen: appAuthProvider.databaseService.getCurrentUserId(): ${appAuthProvider.databaseService.getCurrentUserId()}');


    return Scaffold(
      appBar: AppBar(
        title: const Text('Passenger Dashboard'),
        backgroundColor: AppColors.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookedRides, // Refresh booked rides
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await appAuthProvider.logout();
            },
          ),
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
                  child: appAuthProvider.appUser?.profilePictureUrl == null || appAuthProvider.appUser!.profilePictureUrl!.isEmpty
                      ? const Icon(Icons.person, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, Rider ${appAuthProvider.appUser?.name ?? ''}!',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: _pickAndUploadImage,
                        child: const Text('Change Profile Picture'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: screenSize.height * 0.03),
            CustomButton(
              text: 'Find Rides',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FindRidesScreen()),
                );
                _loadBookedRides(); // Reload booked rides after returning from FindRidesScreen
              },
              color: AppColors.primaryColor,
            ),
            SizedBox(height: screenSize.height * 0.02),
            const Text(
              'Your Booked Rides History:', // Keeping this title as per your provided code
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: screenSize.height * 0.01),
            _isLoadingBookedRides
                ? const Center(child: LoadingIndicator())
                : Expanded(
              child: _bookedRides.isEmpty
                  ? Center(
                child: Text(
                  'No rides booked yet. Find your first ride!',
                  style: TextStyle(color: AppColors.hintColor),
                ),
              )
                  : ListView.builder(
                itemCount: _bookedRides.length,
                itemBuilder: (context, index) {
                  final ride = _bookedRides[index];

                  // --- DEBUG PRINTS START ---
                  print('RiderHome: Processing ride: ${ride.id}');
                  print('RiderHome: AppAuthProvider MongoDB ID: ${appAuthProvider.databaseService.getCurrentUserId()}');
                  print('RiderHome: Ride Passengers count: ${ride.passengers.length}');
                  ride.passengers.forEach((p) {
                    print('  Passenger in ride ${ride.id}: User ID: ${p.userId}, Status: ${p.status}, Booked Seats: ${p.bookedSeats}');
                  });
                  // --- DEBUG PRINTS END ---

                  // Safely find the specific booking details for the current user
                  final currentUserMongoId = appAuthProvider.databaseService.getCurrentUserId();
                  print('RiderHome: Attempting to find booking for MongoDB ID: $currentUserMongoId');

                  final currentUserBooking = ride.passengers.firstWhereOrNull(
                        (p) => p.userId == currentUserMongoId, // CRITICAL FIX HERE
                  );

                  if (currentUserBooking == null) {
                    print('RiderHome: No booking found for current user ($currentUserMongoId) on ride ${ride.id}. Hiding card.');
                    return const SizedBox.shrink();
                  }

                  print('RiderHome: Found booking for current user on ride ${ride.id}. Displaying card.');

                  // Ensure all accessed properties are null-safe
                  final bool isRideActive = ride.status == 'active';
                  final bool isBookingAccepted = currentUserBooking.status == 'accepted';
                  final bool isRideCompleted = ride.status == 'completed';
                  final bool isBookingCompletedByDriver = currentUserBooking.status == 'completed_by_driver';
                  final bool isBookingCancelled = currentUserBooking.status == 'cancelled_by_rider';


                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${ride.from} to ${ride.to}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          // Display driver name and rating (using driverAverageRating and driverNumRatings)
                         // Text('Driver: ${ride.driverName} ${ride.driverAverageRating != null && ride.driverNumRatings != null && ride.driverNumRatings! > 0 ? '(${ride.driverAverageRating!.toStringAsFixed(1)} ★)' : ''}'),
                          // Display driver phone number
                          Text('Driver Contact: ${ride.driverPhone}'),
                          // Format departureTime to local time
                          Text('Departure: ${DateFormat('MMM dd, hh:mm a').format(ride.departureTime)}'),
                          // Format createdAt to local time
                          Text('Posted On: ${DateFormat('MMM dd, hh:mm a').format(ride.createdAt)}'),
                          Text('Price per seat: PKR ${ride.price}'),
                          Text('Seats Booked by you: ${currentUserBooking.bookedSeats}'),
                          Text('Your Pickup: ${currentUserBooking.pickupAddress}'),
                          Text('Your Drop-off: ${currentUserBooking.dropoffAddress}'),
                          Text('Your Contact: ${currentUserBooking.contactPhone}'),
                          Text('Ride Status: ${ride.status.toUpperCase()}'),
                          Text('Booking Status: ${currentUserBooking.status.toUpperCase()}'),
                          if (isBookingCancelled && currentUserBooking.cancellationReason != null && currentUserBooking.cancellationReason!.isNotEmpty)
                            Text('Reason: ${currentUserBooking.cancellationReason}', style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.hintColor)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (isRideActive && isBookingAccepted)
                                Expanded(
                                  child: CustomButton(
                                    text: 'Track Ride',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RideTrackingScreen(ride: ride),
                                        ),
                                      );
                                    },
                                    color: AppColors.infoColor,
                                  ),
                                ),
                              if (isRideActive && isBookingAccepted && ride.departureTime.isAfter(DateTime.now()))
                                const SizedBox(width: 10),
                              if (isRideActive && isBookingAccepted && ride.departureTime.isAfter(DateTime.now()))
                                Expanded(
                                  child: CustomButton(
                                    text: 'Cancel My Booking',
                                    onPressed: () => _showCancelBookingDialog(ride.id),
                                    color: AppColors.errorColor,
                                  ),
                                ),
                              if (isRideCompleted && isBookingCompletedByDriver)
                                Expanded(
                                  child: CustomButton(
                                    text: 'Rate Driver',
                                    onPressed: () => _showRatingDialog(ride.id),
                                    color: AppColors.primaryColor,
                                  ),
                                ),
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
