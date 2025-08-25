import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/providers/auth_provider.dart';
import 'package:ride_share_app/services/database_service.dart';
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
  final _priceController = TextEditingController();
  final _seatsController = TextEditingController();

  // State for map and location
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  LatLng? _origin;
  LatLng? _destination;
  String _originAddress = 'Tap map to select origin';
  String _destinationAddress = 'Tap map to select destination';
  final LatLng _initialCameraPosition = const LatLng(31.5204, 74.3587); // Default to Lahore
  int? _suggestedPrice;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _priceController.dispose();
    _seatsController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> _getCurrentLocation() async {
    Location location = Location();
    bool serviceEnabled;
    PermissionStatus permissionGranted;
    LocationData locationData;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    locationData = await location.getLocation();
    final currentLatLng = LatLng(locationData.latitude!, locationData.longitude!);

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(currentLatLng, 15));
    _handleMapTap(currentLatLng);
  }

  void _handleMapTap(LatLng location) {
    if (_origin == null || (_origin != null && _destination != null)) {
      _setOrigin(location);
      _destination = null;
      _destinationAddress = 'Tap map to select destination';
      _markers.removeWhere((m) => m.markerId.value == 'destination');
    } else {
      _setDestination(location);
    }
  }

  Future<void> _setOrigin(LatLng location) async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      final address = await dbService.reverseGeocode(location.latitude, location.longitude);
      setState(() {
        _origin = location;
        _originAddress = address;
        _markers.add(
          Marker(
            markerId: const MarkerId('origin'),
            position: location,
            infoWindow: InfoWindow(title: 'Origin', snippet: address),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      });
      _calculateFare();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get address: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setDestination(LatLng location) async {
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      final address = await dbService.reverseGeocode(location.latitude, location.longitude);
      setState(() {
        _destination = location;
        _destinationAddress = address;
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: location,
            infoWindow: InfoWindow(title: 'Destination', snippet: address),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      });
      _calculateFare();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get address: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateFare() async {
    if (_origin == null || _destination == null) return;
    setState(() => _isLoading = true);
    try {
      final dbService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      final result = await dbService.calculateFare(_originAddress, _destinationAddress);
      setState(() {
        _suggestedPrice = result['suggestedPrice'];
        _priceController.text = _suggestedPrice.toString();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to calculate fare: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null && picked != _selectedDate) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _selectedTime ?? TimeOfDay.now());
    if (picked != null && picked != _selectedTime) setState(() => _selectedTime = picked);
  }

  Future<void> _postRide() async {
    if (_origin == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select origin and destination on the map.')));
      return;
    }
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select both date and time for the ride.')));
        return;
      }
      setState(() => _isLoading = true);
      try {
        final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
        final databaseService = authProvider.databaseService;
        final DateTime localDepartureDateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
        final String departureTimeString = localDepartureDateTime.toIso8601String();
        final rideData = {
          'from': _originAddress,
          'to': _destinationAddress,
          'price': int.parse(_priceController.text.trim()),
          'seats': int.parse(_seatsController.text.trim()),
          'departureTime': departureTimeString,
        };
        await databaseService.postRide(rideData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride posted successfully!')));
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post ride: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(title: const Text('Post a New Ride'), backgroundColor: AppColors.primaryColor),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 300,
                      decoration: BoxDecoration(border: Border.all(color: AppColors.primaryColor), borderRadius: BorderRadius.circular(10)),
                      child: GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(target: _initialCameraPosition, zoom: 12),
                        markers: _markers,
                        onTap: _handleMapTap,
                      ),
                    ),
                    SizedBox(height: screenSize.height * 0.02),
                    CustomButton(text: 'Use My Current Location for Origin', onPressed: _getCurrentLocation, color: AppColors.secondaryColor),
                    SizedBox(height: screenSize.height * 0.02),
                    ListTile(leading: const Icon(Icons.my_location, color: AppColors.primaryColor), title: const Text('From'), subtitle: Text(_originAddress)),
                    ListTile(leading: const Icon(Icons.location_on, color: AppColors.secondaryColor), title: const Text('To'), subtitle: Text(_destinationAddress)),
                    if (_suggestedPrice != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Suggested Fare: PKR $_suggestedPrice', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryColor))),
                    SizedBox(height: screenSize.height * 0.02),
                    CustomTextField(controller: _priceController, labelText: 'Price per Seat (PKR)', keyboardType: TextInputType.number, validator: (value) { if (value == null || value.isEmpty) return 'Price is required.'; if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Please enter a valid price.'; return null; }),
                    SizedBox(height: screenSize.height * 0.02),
                    CustomTextField(controller: _seatsController, labelText: 'Total Seats Offered', keyboardType: TextInputType.number, validator: (value) { if (value == null || value.isEmpty) return 'Number of seats is required.'; if (int.tryParse(value) == null || int.parse(value) <= 0) return 'Please enter a valid number of seats.'; return null; }),
                    SizedBox(height: screenSize.height * 0.03),
                    Row(
                      children: [
                        Expanded(child: CustomButton(text: _selectedDate == null ? 'Select Date' : DateFormat('MMM dd, yyyy').format(_selectedDate!), onPressed: () => _selectDate(context), color: AppColors.infoColor)),
                        const SizedBox(width: 10),
                        Expanded(child: CustomButton(text: _selectedTime == null ? 'Select Time' : _selectedTime!.format(context), onPressed: () => _selectTime(context), color: AppColors.infoColor)),
                      ],
                    ),
                    SizedBox(height: screenSize.height * 0.04),
                    CustomButton(text: 'Post Ride', onPressed: _postRide, color: AppColors.primaryColor),
                  ],
                ),
              ),
            ),
    );
  }
}
