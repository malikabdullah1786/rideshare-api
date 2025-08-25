import 'package:cloud_firestore/cloud_firestore.dart';

// A simple class to hold latitude and longitude.
class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});

  // Factory constructor to create a Location from a map (like the one from backend)
  factory Location.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      // Return a default or handle the error as appropriate for your app
      return Location(latitude: 0.0, longitude: 0.0);
    }
    return Location(
      // Safely parse the latitude and longitude, providing defaults if null
      latitude: (data['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }
}



// New model for individual passenger bookings within a ride

class PassengerBooking {

  final String userId; // ID of the rider who booked

  final int bookedSeats;

  final String pickupAddress;

  final String dropoffAddress;

  final String contactPhone;

  final String status; // 'accepted', 'pending', 'cancelled_by_rider', 'completed_by_driver'

  final DateTime createdAt;

  final String? userName; // Populated from backend

  final String? userEmail; // Populated from backend

  final String? userCnic; // Populated from backend

  final String? cancellationReason; // NEW: Reason for rider cancelling this specific booking



  PassengerBooking({

    required this.userId,

    required this.bookedSeats,

    required this.pickupAddress,

    required this.dropoffAddress,

    required this.contactPhone,

    required this.status,

    required this.createdAt,

    this.userName,

    this.userEmail,

    this.userCnic,

    this.cancellationReason, // NEW

  });



  factory PassengerBooking.fromMap(Map<String, dynamic> data) {

// Handle populated 'user' field (which is an object) or just the user ID string

    String extractedUserId;

    String? extractedUserName;

    String? extractedUserEmail;

    String? extractedUserCnic;



    if (data['user'] is Map) {

      extractedUserId = data['user']['_id'] ?? '';

      extractedUserName = data['user']['name'];

      extractedUserEmail = data['user']['email'];

      extractedUserCnic = data['user']['cnic'];

    } else {

      extractedUserId = data['user'] ?? ''; // It's just the ID string

    }



    return PassengerBooking(

      userId: extractedUserId,

      bookedSeats: data['bookedSeats'] ?? 0,

      pickupAddress: data['pickupAddress'] ?? '',

      dropoffAddress: data['dropoffAddress'] ?? '',

      contactPhone: data['contactPhone'] ?? '',

      status: data['status'] ?? 'accepted',

      createdAt: data['createdAt'] != null

          ? DateTime.parse(data['createdAt'])

          : DateTime.now(),

      userName: extractedUserName,

      userEmail: extractedUserEmail,

      userCnic: extractedUserCnic,

      cancellationReason: data['cancellationReason'], // NEW

    );

  }



  Map<String, dynamic> toMap() {

    return {

      'user': userId,

      'bookedSeats': bookedSeats,

      'pickupAddress': pickupAddress,

      'dropoffAddress': dropoffAddress,

      'contactPhone': contactPhone,

      'status': status,

      'createdAt': createdAt.toIso8601String(),

      'cancellationReason': cancellationReason, // NEW

    };

  }

}



class Ride {

  final String id;

  final String driverId;

  final String driverName; // Driver's name, now stored directly

  final String driverPhone; // Driver's phone, now stored directly

  final double? driverRating; // Driver's average rating (still populated)

  final String from;

  final String to;

  final Location origin;

  final Location destination;

  final int price;

  final int seats;

  final int seatsAvailable;

  final DateTime departureTime;

  final DateTime createdAt;

  final String status; // 'active', 'completed', 'cancelled'

  final List<PassengerBooking> passengers; // Now a list of PassengerBooking objects

  final String? cancellationReason; // Reason for driver cancelling the entire ride



  Ride({

    required this.id,

    required this.driverId,

    required this.driverName, // Now required

    required this.driverPhone, // Now required

    this.driverRating, // Can be null if no ratings

    required this.from,

    required this.to,

    required this.origin,

    required this.destination,

    required this.price,

    required this.seats,

    required this.seatsAvailable,

    required this.departureTime,

    required this.createdAt,

    required this.status,

    this.passengers = const [], // Initialize as empty list

    this.cancellationReason, // NEW

  });



  factory Ride.fromMap(Map<String, dynamic> data) {

    var passengersList = <PassengerBooking>[];

    if (data['passengers'] != null) {

      passengersList = (data['passengers'] as List)

          .map((p) => PassengerBooking.fromMap(p as Map<String, dynamic>))

          .toList();

    }



// Driver ID is still from 'driver' field, but name/phone are now direct fields

    String extractedDriverId;

    double? extractedDriverRating;



    if (data['driver'] is Map) {

      extractedDriverId = data['driver']['_id'] ?? '';

// Rating is still populated from the 'driver' object

      extractedDriverRating = (data['driver']['averageRating'] as num?)?.toDouble();

    } else {

      extractedDriverId = data['driver'] ?? ''; // It's just the ID string

    }



// Parse departureTime. If the ISO string had an offset, it will be a local DateTime.

// If it was a 'Z' (UTC) string, it will be a UTC DateTime.

    final DateTime parsedDepartureTime = DateTime.parse(data['departureTime']);



// createdAt is always UTC from MongoDB. Convert it to local for consistent display.

    final DateTime parsedCreatedAt = DateTime.parse(data['createdAt']).toLocal();





    return Ride(

      id: data['_id'], // MongoDB uses _id

      driverId: extractedDriverId,

      driverName: data['driverName'] ?? 'Unknown Driver', // Read directly from ride data

      driverPhone: data['driverPhone'] ?? 'N/A', // Read directly from ride data

      driverRating: extractedDriverRating, // Still from populated driver object

      from: data['from'],

      to: data['to'],
      origin: Location.fromMap(data['origin'] as Map<String, dynamic>?),
      destination: Location.fromMap(data['destination'] as Map<String, dynamic>?),
      price: data['price'],

      seats: data['seats'],

      seatsAvailable: data['seatsAvailable'],

      departureTime: parsedDepartureTime,

      createdAt: parsedCreatedAt, // Use the converted local time

      status: data['status'],

      passengers: passengersList,

      cancellationReason: data['cancellationReason'], // NEW

    );

  }



// Convert Ride to a map for sending to your backend (for MongoDB) - primarily for posting

  Map<String, dynamic> toMap() {

    return {

      'driver': driverId, // Backend expects 'driver' not 'driverId' for creation

      'driverName': driverName, // Include driver name

      'driverPhone': driverPhone, // Include driver phone

      'from': from,

      'to': to,

      'price': price,

      'seats': seats,

      'seatsAvailable': seatsAvailable,

      'departureTime': departureTime.toIso8601String(), // This will include the offset

      'createdAt': createdAt.toIso8601String(), // This will also include the offset

      'status': status,

      'passengers': passengers.map((p) => p.toMap()).toList(),

      'cancellationReason': cancellationReason, // NEW

    };

  }

}