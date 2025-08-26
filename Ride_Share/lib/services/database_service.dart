import 'dart:convert';

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:ride_share_app/models/user_model.dart';

import 'package:flutter/material.dart'; // Import for TimeOfDay

import 'package:ride_share_app/models/ride_model.dart'; // Import Ride and PassengerBooking



// IMPORTANT: Set this base URL correctly based on your Flutter app's running environment.

// Choose ONE of the following by uncommenting the relevant line:



// For Android Emulator (most common for Android development):

// const String _baseUrl = 'http://10.0.2.2:5000/api';



// For iOS Simulator or Web Browser (most common for Apple/Web development):

//const String _baseUrl = 'http://localhost:5000/api'; // This is often the default you need

const String _baseUrl = 'https://rideshare-api-uauj.onrender.com/api';

// For Physical Android Device (requires your computer's actual IP address):

// You MUST replace 'YOUR_COMPUTERS_IP_ADDRESS' with your actual local network IP (e.g., 192.168.1.5).

// You can find your IP by running 'ipconfig' (Windows) or 'ifconfig' / 'ip a' (macOS/Linux) in your terminal.

// const String _baseUrl = 'http://YOUR_COMPUTERS_IP_ADDRESS:5000/api';


class DatabaseService {

  String? _authToken;
  String? _currentMongoUserId; // Field to store the MongoDB user ID


  void setAuthToken(String? token) {
    _authToken = token;

    print("DatabaseService: Auth token set: $_authToken");
  }

  String? getCurrentUserId() {
    return _currentMongoUserId;
  }

  void _setMongoUserId(String? userId) {
    _currentMongoUserId = userId;
    print("DatabaseService: Current Mongo User ID set: $_currentMongoUserId");
  }


  Map<String, String> _getHeaders() {
    final Map<String, String> headers = {

      'Content-Type': 'application/json',

    };

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';

// --- DEBUG PRINT START ---

      print(
          'DatabaseService: Full Auth Token in Headers: $_authToken'); // Log the full token

// --- DEBUG PRINT END ---

    }

// --- DEBUG PRINT START ---

    print('DatabaseService: Headers being sent: $headers');

// --- DEBUG PRINT END ---

    return headers;
  }


// --- User Profile Operations ---


  Future<Map<String, dynamic>> registerUserProfile(
      Map<String, dynamic> userData) async {
    try {
      final response = await http.post(

        Uri.parse('$_baseUrl/auth/register'),

        headers: {'Content-Type': 'application/json'},

        body: json.encode(userData),

      );


      final responseData = json.decode(response.body);


      if (response.statusCode == 201) {
        print("Backend: User registered and profile saved successfully.");
        // MODIFIED: Add null check for responseData['user']
        if (responseData['user'] != null && responseData['user'] is Map) {
          _setMongoUserId(responseData['user']['_id']);
        } else {
          print("DatabaseService: Warning: 'user' field in register response is null or not a map.");
        }

        return responseData;
      } else {
        print("Backend Error (Register): ${responseData['message']}");

        throw Exception(responseData['message'] ??
            'Failed to register user and save profile');
      }
    } catch (e) {
      print("Error registering user profile: $e");

      rethrow;
    }
  }


  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final response = await http.post(

        Uri.parse('$_baseUrl/auth/login'),

        headers: {'Content-Type': 'application/json'},

        body: json.encode({'email': email, 'password': password}),

      );


      final responseData = json.decode(response.body);


      if (response.statusCode == 200) {
        print("Backend: User logged in successfully.");
        // MODIFIED: Add null check for responseData['user']
        if (responseData['user'] != null && responseData['user'] is Map) {
          _setMongoUserId(responseData['user']['_id']);
        } else {
          print("DatabaseService: Warning: 'user' field in login response is null or not a map.");
        }

        return responseData;
      } else {
        print("Backend Error (Login): ${responseData['message']}");

        throw Exception(responseData['message'] ?? 'Failed to login user');
      }
    } catch (e) {
      print("Error logging in user: $e");

      rethrow;
    }
  }


  Future<Map<String, dynamic>?> getUserProfile(String firebaseUid) async {
    try {
      final response = await http.get(

        Uri.parse('$_baseUrl/auth/profile'),

        headers: _getHeaders(), // Use the _getHeaders method

      );


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        print("Backend: Retrieved user profile for UID: $firebaseUid");
        // MODIFIED: Add null check for data['user']
        if (data['user'] != null && data['user'] is Map) {
          _setMongoUserId(data['user']['_id']);
        } else {
          print("DatabaseService: Warning: 'user' field in get profile response is null or not a map.");
        }

        return data;
      } else if (response.statusCode == 404) {
        print(
            "Backend: Profile not found for UID: $firebaseUid (might be new user)");

        return null;
      } else {
        final errorData = json.decode(response.body);

        print("Backend Error (Get Profile): ${errorData['message']}");

        throw Exception(errorData['message'] ?? 'Failed to get user profile');
      }
    } catch (e) {
      print("Error getting user profile: $e");

      rethrow;
    }
  }


  Future<String> uploadProfilePicture(XFile image) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/users/profile/upload'),
      );
      request.headers.addAll(_getHeaders());
      request.files.add(await http.MultipartFile.fromPath('profilePicture', image.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final decodedData = json.decode(responseData);
        return decodedData['profilePictureUrl'];
      } else {
        final responseData = await response.stream.bytesToString();
        final errorData = json.decode(responseData);
        print("Backend Error (Upload Profile Picture): ${errorData['message']}");
        throw Exception(errorData['message'] ?? 'Failed to upload profile picture');
      }
    } catch (e) {
      print("Error uploading profile picture: $e");
      rethrow;
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> userData) async {
    try {
      final response = await http.put(

        Uri.parse('$_baseUrl/auth/profile'),

        headers: _getHeaders(),

        body: json.encode(userData),

      );


      final responseData = json.decode(response.body);


      if (response.statusCode == 200) {
        print("Backend: User profile updated successfully.");
      } else {
        print("Backend Error (Update Profile): ${responseData['message']}");

        throw Exception(
            responseData['message'] ?? 'Failed to update user profile');
      }
    } catch (e) {
      print("Error updating user profile: $e");

      rethrow;
    }
  }


// --- Ride Operations ---


  Future<Map<String, dynamic>> postRide(Map<String, dynamic> rideData) async {
    try {
      final response = await http.post(

        Uri.parse('$_baseUrl/rides/post'),

        headers: _getHeaders(),

        body: json.encode(rideData),

      );


      final responseData = json.decode(response.body);


      if (response.statusCode == 201) {
        print("Backend: Ride posted successfully.");

        return responseData;
      } else {
        print("Backend Error (Post Ride): ${responseData['message']}");

        throw Exception(responseData['message'] ?? 'Failed to post ride');
      }
    } catch (e) {
      print("Error posting ride: $e");

      rethrow;
    }
  }


  Future<List<dynamic>> getRides(
      {String? from, String? to, DateTime? date, TimeOfDay? time}) async {
    try {
      final Map<String, String> queryParams = {};

      if (from != null && from.isNotEmpty) queryParams['from'] = from;

      if (to != null && to.isNotEmpty) queryParams['to'] = to;

      if (date != null)
        queryParams['date'] = date.toIso8601String().split('T')[0];

      if (time != null) queryParams['time'] =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(
          2, '0')}';


      final uri = Uri.parse('$_baseUrl/rides').replace(
          queryParameters: queryParams);


      final response = await http.get(

        uri,

        headers: _getHeaders(),

      );


      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);

        print(
            "Backend Error (Get Rides with Filters): ${errorData['message']}");

        throw Exception(
            errorData['message'] ?? 'Failed to fetch rides with filters');
      }
    } catch (e) {
      print("Error getting rides with filters: $e");

      rethrow;
    }
  }


  Future<List<dynamic>> searchRides(String from, String to) async {
    return getRides(from: from, to: to);
  }


// Updated bookRide to send passenger details

  Future<Map<String, dynamic>> bookRide(String rideId,
      List<Map<String, dynamic>> passengersToBook) async {
    try {
// DEBUG PRINT: See what's being sent to the backend

      print(
          'DatabaseService: Sending booking request for ride $rideId with data: ${json
              .encode({'passengersToBook': passengersToBook})}');


      final response = await http.post(

        Uri.parse('$_baseUrl/rides/$rideId/book'),

        headers: _getHeaders(),

        body: json.encode({
          'passengersToBook': passengersToBook
        }), // Send array of passenger details

      );


      final responseData = json.decode(response.body);


      if (response.statusCode == 200) {
        print("Backend: Ride booked successfully.");

        return responseData;
      } else {
        print("Backend Error (Book Ride): ${responseData['message']}");

        throw Exception(responseData['message'] ?? 'Failed to book ride');
      }
    } catch (e) {
      print("Error booking ride: $e");

      rethrow;
    }
  }


// New: Cancel a ride booking by a rider (now accepts a reason)

  Future<void> cancelBooking(String rideId, String? reason) async {
    try {
      final response = await http.put(

        Uri.parse('$_baseUrl/rides/$rideId/cancel-booking'),

        headers: _getHeaders(),

        body: json.encode({'cancellationReason': reason}), // Send reason

      );


      final responseData = json.decode(response.body);


      if (response.statusCode == 200) {
        print("Backend: Ride booking cancelled successfully.");
      } else {
        print("Backend Error (Cancel Booking): ${responseData['message']}");

        throw Exception(responseData['message'] ?? 'Failed to cancel booking');
      }
    } catch (e) {
      print("Error cancelling booking: $e");

      rethrow;
    }
  }


// New: Cancel a posted ride by a driver (now accepts a reason)

  Future<void> cancelRide(String rideId, String? reason) async {
    try {
      final response = await http.put(

        Uri.parse('$_baseUrl/rides/$rideId/cancel-ride'),

        headers: _getHeaders(),

        body: json.encode({'cancellationReason': reason}), // Send reason

      );


      final responseData = json.decode(response.body);


      if (response.statusCode == 200) {
        print("Backend: Ride cancelled successfully by driver.");
      } else {
        print("Backend Error (Cancel Ride): ${responseData['message']}");

        throw Exception(responseData['message'] ?? 'Failed to cancel ride');
      }
    } catch (e) {
      print("Error cancelling ride: $e");

      rethrow;
    }
  }


// New: Mark a ride as completed by a driver

  Future<void> completeRide(String rideId) async {
    try {
      final response = await http.put(

        Uri.parse('$_baseUrl/rides/$rideId/complete-ride'),

        headers: _getHeaders(),

      );


      final responseData = json.decode(response.body);


      if (response.statusCode == 200) {
        print("Backend: Ride marked as completed successfully.");
      } else {
        print("Backend Error (Complete Ride): ${responseData['message']}");

        throw Exception(responseData['message'] ?? 'Failed to complete ride');
      }
    } catch (e) {
      print("Error completing ride: $e");

      rethrow;
    }
  }


  Future<List<dynamic>> getMyPostedRides() async {
    try {
      final response = await http.get(

        Uri.parse('$_baseUrl/rides/my-posted-rides'),

        headers: _getHeaders(),

      );


      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);

        print("Backend Error (My Posted Rides): ${errorData['message']}");

        throw Exception(errorData['message'] ?? 'Failed to fetch posted rides');
      }
    } catch (e) {
      print("Error fetching posted rides: $e");

      rethrow;
    }
  }


  Future<List<dynamic>> getMyBookedRides() async {
    try {
      final response = await http.get(

        Uri.parse('$_baseUrl/rides/my-booked-rides'),

        headers: _getHeaders(),

      );


      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);

        print("Backend Error (My Booked Rides): ${errorData['message']}");

        throw Exception(errorData['message'] ?? 'Failed to fetch booked rides');
      }
    } catch (e) {
      print("Error fetching booked rides: $e");

      rethrow;
    }
  }


// New: Get driver earnings

  Future<Map<String, dynamic>> getDriverEarnings() async {
    try {
      final response = await http.get(

        Uri.parse('$_baseUrl/rides/earnings'),

        headers: _getHeaders(),

      );


      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);

        print("Backend Error (Get Earnings): ${errorData['message']}");

        throw Exception(
            errorData['message'] ?? 'Failed to fetch driver earnings');
      }
    } catch (e) {
      print("Error getting earnings: $e");

      rethrow;
    }
  }


// New: Rate a driver

  Future<void> rateDriver(String rideId, int rating) async {
    try {
      final response = await http.post(

        Uri.parse('$_baseUrl/rides/$rideId/rate-driver'),

        headers: _getHeaders(),

        body: json.encode({'rating': rating}),

      );


      final responseData = json.decode(response.body);


      if (response.statusCode == 200) {
        print("Backend: Driver rated successfully.");
      } else {
        print("Backend Error (Rate Driver): ${responseData['message']}");

        throw Exception(responseData['message'] ?? 'Failed to rate driver');
      }
    } catch (e) {
      print("Error rating driver: $e");

      rethrow;
    }
  }

  // --- Map & Fare Operations ---

  Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/maps/reverse-geocode'),
        headers: _getHeaders(),
        body: json.encode({'lat': lat, 'lng': lng}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['address'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to reverse geocode.');
      }
    } catch (e) {
      print("Error reverse geocoding: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> calculateFare(String from, String to) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rides/calculate-fare'),
        headers: _getHeaders(),
        body: json.encode({'from': from, 'to': to}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to calculate fare.');
      }
    } catch (e) {
      print("Error calculating fare: $e");
      rethrow;
    }
  }

  // --- Admin Operations ---

  Future<List<dynamic>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/users'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorData = json.decode(response.body);
        print("Backend Error (Get All Users): ${errorData['message']}");
        throw Exception(errorData['message'] ?? 'Failed to fetch users');
      }
    } catch (e) {
      print("Error getting all users: $e");
      rethrow;
    }
  }

  Future<void> approveUser(String userId) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/users/$userId/approve'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        print("Backend Error (Approve User): ${errorData['message']}");
        throw Exception(errorData['message'] ?? 'Failed to approve user');
      }
    } catch (e) {
      print("Error approving user: $e");
      rethrow;
    }
  }

  Future<void> adminCancelRide(String rideId, String reason) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/admin/rides/$rideId/cancel'),
        headers: _getHeaders(),
        body: json.encode({'cancellationReason': reason}),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to cancel ride as admin.');
      }
    } catch (e) {
      print("Error cancelling ride as admin: $e");
      rethrow;
    }
  }
}
