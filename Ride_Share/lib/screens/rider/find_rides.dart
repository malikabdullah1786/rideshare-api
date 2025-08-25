import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/providers/auth_provider.dart';
import 'package:ride_share_app/widgets/custom_button.dart';
import 'package:ride_share_app/widgets/custom_textfield.dart';
import 'package:ride_share_app/widgets/loading_indicator.dart';
import 'package:ride_share_app/models/ride_model.dart';
import 'package:ride_share_app/models/user_model.dart'; // Import AppUser

class FindRidesScreen extends StatefulWidget {
  const FindRidesScreen({super.key});

  @override
  State<FindRidesScreen> createState() => _FindRidesScreenState();
}

class _FindRidesScreenState extends State<FindRidesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  DateTime? _selectedDateFilter;
  TimeOfDay? _selectedTimeFilter;

  bool _isLoading = false;
  List<Ride> _foundRides = [];

  @override
  void initState() {
    super.initState();
    _loadAllRides();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _loadAllRides() async {
    setState(() {
      _isLoading = true;
      _foundRides = [];
    });

    try {
      final databaseService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      final List<dynamic> rideMaps = await databaseService.getRides();

      setState(() {
        _foundRides = rideMaps.map((map) => Ride.fromMap(map)).toList();
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load rides: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateFilter(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateFilter ?? DateTime.now(),
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
    if (picked != null && picked != _selectedDateFilter) {
      setState(() => _selectedDateFilter = picked);
    }
  }

  Future<void> _selectTimeFilter(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimeFilter ?? TimeOfDay.now(),
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
    if (picked != null && picked != _selectedTimeFilter) {
      setState(() => _selectedTimeFilter = picked);
    }
  }

  Future<void> _applyFilters() async {
    setState(() {
      _isLoading = true;
      _foundRides = [];
    });

    try {
      final databaseService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      final List<dynamic> rideMaps = await databaseService.getRides(
        from: _fromController.text.trim().isEmpty ? null : _fromController.text.trim(),
        to: _toController.text.trim().isEmpty ? null : _toController.text.trim(),
        date: _selectedDateFilter,
        time: _selectedTimeFilter,
      );

      setState(() {
        _foundRides = rideMaps.map((map) => Ride.fromMap(map)).toList();
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_foundRides.length} rides found with filters.'),
            backgroundColor: AppColors.secondaryColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply filters: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showBookingDialog(Ride ride) async {
    final AppUser? currentUser = Provider.of<AppAuthProvider>(context, listen: false).appUser;
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to book a ride.')),
        );
      }
      return;
    }

    final List<TextEditingController> pickupControllers = [TextEditingController(text: currentUser.address)];
    final List<TextEditingController> dropoffControllers = [TextEditingController()];
    final List<TextEditingController> phoneControllers = [TextEditingController(text: currentUser.phone)];
    final List<int> seatsToBookList = [1]; // Default 1 seat for primary rider

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Book Ride Details'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Booking for ride from ${ride.from} to ${ride.to}'),
                    Text('Price per seat: PKR ${ride.price}'),
                    Text('Seats available: ${ride.seatsAvailable}'),
                    const SizedBox(height: 20),
                    ...List.generate(seatsToBookList.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              index == 0 ? 'Your Details:' : 'Rider ${index + 1} Details:',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            CustomTextField(
                              controller: pickupControllers[index],
                              labelText: 'Pickup Address',
                              validator: (value) => value!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),
                            CustomTextField(
                              controller: dropoffControllers[index],
                              labelText: 'Drop-off Address',
                              validator: (value) => value!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),
                            CustomTextField(
                              controller: phoneControllers[index],
                              labelText: 'Contact Phone Number',
                              keyboardType: TextInputType.phone,
                              validator: (value) => value!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),
                            // Number of seats for this specific passenger (default 1)
                            Text('Seats for this person: ${seatsToBookList[index]}'),
                            if (index == 0 && ride.seatsAvailable > 1) // Only primary rider can add more seats
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    if (seatsToBookList.reduce((a, b) => a + b) < ride.seatsAvailable!) {
                                      setState(() {
                                        seatsToBookList[index]++;
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No more seats available!')),
                                      );
                                    }
                                  },
                                  child: const Text('Add Another Seat for Me'),
                                ),
                              ),
                            if (index == 0 && ride.seatsAvailable > seatsToBookList.reduce((a, b) => a + b))
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    if (seatsToBookList.reduce((a, b) => a + b) < ride.seatsAvailable!) {
                                      setState(() {
                                        pickupControllers.add(TextEditingController());
                                        dropoffControllers.add(TextEditingController());
                                        phoneControllers.add(TextEditingController());
                                        seatsToBookList.add(1); // Add 1 seat for the new person
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No more seats available!')),
                                      );
                                    }
                                  },
                                  child: const Text('Add Another Person'),
                                ),
                              ),
                            if (index > 0)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      pickupControllers[index].dispose();
                                      dropoffControllers[index].dispose();
                                      phoneControllers[index].dispose();
                                      pickupControllers.removeAt(index);
                                      dropoffControllers.removeAt(index);
                                      phoneControllers.removeAt(index);
                                      seatsToBookList.removeAt(index);
                                    });
                                  },
                                  child: const Text('Remove This Person'),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    Text(
                      'Total seats to book: ${seatsToBookList.reduce((a, b) => a + b)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Dismiss dialog
                  },
                ),
                CustomButton(
                  text: 'Confirm Booking',
                  onPressed: () async {
                    // Collect all passenger data
                    List<Map<String, dynamic>> passengersData = [];
                    for (int i = 0; i < seatsToBookList.length; i++) {
                      passengersData.add({
                        'bookedSeats': seatsToBookList[i],
                        'pickupAddress': pickupControllers[i].text.trim(),
                        'dropoffAddress': dropoffControllers[i].text.trim(),
                        'contactPhone': phoneControllers[i].text.trim(),
                      });
                    }

                    // Validate all fields before proceeding
                    bool allFieldsValid = true;
                    for (int i = 0; i < passengersData.length; i++) {
                      if (passengersData[i]['pickupAddress'].isEmpty ||
                          passengersData[i]['dropoffAddress'].isEmpty ||
                          passengersData[i]['contactPhone'].isEmpty) {
                        allFieldsValid = false;
                        break;
                      }
                    }

                    if (!allFieldsValid) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all pickup, drop-off, and phone details for all passengers.'),
                            backgroundColor: AppColors.errorColor,
                          ),
                        );
                      }
                      return;
                    }

                    // Dispose controllers after use
                    for (var controller in pickupControllers) controller.dispose();
                    for (var controller in dropoffControllers) controller.dispose();
                    for (var controller in phoneControllers) controller.dispose();

                    Navigator.of(dialogContext).pop(); // Dismiss dialog before API call
                    await _bookRide(ride.id, passengersData);
                  },
                  color: AppColors.primaryColor,
                  width: 150,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _bookRide(String rideId, List<Map<String, dynamic>> passengersToBook) async {
    setState(() => _isLoading = true);
    try {
      final databaseService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      await databaseService.bookRide(rideId, passengersToBook);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride booked successfully!'),
            backgroundColor: AppColors.secondaryColor,
          ),
        );
        _applyFilters(); // Refresh rides
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book ride: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Rides'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: _selectedDateFilter == null
                              ? 'Select Date'
                              : DateFormat('MMM dd, yyyy').format(_selectedDateFilter!),
                          onPressed: () => _selectDateFilter(context),
                          color: AppColors.secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomButton(
                          text: _selectedTimeFilter == null
                              ? 'Select Time'
                              : _selectedTimeFilter!.format(context),
                          onPressed: () => _selectTimeFilter(context),
                          color: AppColors.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  CustomTextField(
                    controller: _fromController,
                    labelText: 'Departure Location (optional)',
                  ),
                  const SizedBox(height: 15),
                  CustomTextField(
                    controller: _toController,
                    labelText: 'Destination (optional)',
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: 'Apply Filters',
                    onPressed: _applyFilters,
                    color: AppColors.primaryColor,
                  ),
                  const SizedBox(height: 10),
                  CustomButton(
                    text: 'Clear Filters & Show All',
                    onPressed: () {
                      _fromController.clear();
                      _toController.clear();
                      setState(() {
                        _selectedDateFilter = null;
                        _selectedTimeFilter = null;
                      });
                      _loadAllRides();
                    },
                    color: AppColors.hintColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Available Rides:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _foundRides.isEmpty
                ? Center(
              child: Text(
                'No rides found for your criteria.',
                style: TextStyle(color: AppColors.hintColor),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _foundRides.length,
              itemBuilder: (context, index) {
                final ride = _foundRides[index];
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
                        Text('Driver: ${ride.driverName}'), // Will show driver ID, you can populate name later
                        Text('Driver Number: ${ride.driverPhone}'),
                        Text('Driver id: ${ride.driverId}'),
                        Text('Departure: ${DateFormat('MMM dd, hh:mm a').format(ride.departureTime)}'),
                        Text('Price: PKR ${ride.price}'),
                        Text('Seats Available: ${ride.seatsAvailable}/${ride.seats}'),
                        const SizedBox(height: 10),
                        if (ride.seatsAvailable > 0)
                          CustomButton(
                            text: 'Book Ride', // Changed from "Book 1 Seat"
                            onPressed: () => _showBookingDialog(ride), // Show dialog for booking
                            color: AppColors.secondaryColor,
                            width: 150,
                          )
                        else
                          const Text(
                            'No seats available',
                            style: TextStyle(color: AppColors.errorColor),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
