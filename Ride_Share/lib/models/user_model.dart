// No longer needs cloud_firestore.dart if not directly interacting with Firestore
// import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String firebaseUid; // Firebase User ID
  final String email;
  final String name;
  final String? cnic;
  final String phone;
  final String address;
  final String? emergencyContact;
  final String? gender;
  final int? age;
  final String userType; // 'driver' or 'rider'
  final bool emailVerified; // From Firebase Auth
  final bool profileCompleted; // Indicates if extended profile is saved to MongoDB
  final bool isApproved; // New field for admin approval
  final String? profilePictureUrl;
  final String? carModel; // Driver specific
  final String? carRegistration; // Driver specific
  final int? seatsAvailable; // Driver specific
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.name,
    this.cnic,
    required this.phone,
    required this.address,
    this.emergencyContact,
    this.gender,
    this.age,
    required this.userType,
    this.emailVerified = false, // Default from Firebase Auth
    this.profileCompleted = false, // Default to false until MongoDB profile is saved
    this.isApproved = false, // Default to false
    this.profilePictureUrl,
    this.carModel,
    this.carRegistration,
    this.seatsAvailable,
    required this.createdAt,
  });

  // Factory constructor to create an AppUser from a map (e.g., from your MongoDB backend)
  factory AppUser.fromMap(Map<String, dynamic> data) {
    return AppUser(
      id: data['_id'] ?? '',
      firebaseUid: data['firebaseUid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      cnic: data['cnic'],
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      emergencyContact: data['emergencyContact'],
      gender: data['gender'],
      age: data['age'],
      userType: data['userType'] ?? 'rider',
      emailVerified: data['emailVerified'] ?? false,
      profileCompleted: data['profileCompleted'] ?? false,
      isApproved: data['isApproved'] ?? false,
      profilePictureUrl: data['profilePictureUrl'],
      carModel: data['carModel'],
      carRegistration: data['carRegistration'],
      seatsAvailable: data['seatsAvailable'],
      // Assuming createdAt is stored as ISO 8601 string or similar in MongoDB
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
    );
  }

  // Convert AppUser to a map for sending to your MongoDB backend
  Map<String, dynamic> toMap() {
    return {
      'firebaseUid': firebaseUid,
      'email': email,
      'name': name,
      'cnic': cnic,
      'phone': phone,
      'address': address,
      'emergencyContact': emergencyContact,
      'gender': gender,
      'age': age,
      'userType': userType,
      'emailVerified': emailVerified,
      'profileCompleted': profileCompleted,
      'carModel': carModel,
      'carRegistration': carRegistration,
      'seatsAvailable': seatsAvailable,
      'createdAt': createdAt.toIso8601String(), // Store as ISO 8601 string
    };
  }

  // Method to create a copy with updated fields
  AppUser copyWith({
    String? firebaseUid,
    String? email,
    String? name,
    String? cnic,
    String? phone,
    String? address,
    String? emergencyContact,
    String? gender,
    int? age,
    String? userType,
    bool? emailVerified,
    bool? profileCompleted,
    bool? isApproved,
    String? profilePictureUrl,
    String? carModel,
    String? carRegistration,
    int? seatsAvailable,
    DateTime? createdAt,
  }) {
    return AppUser(
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      name: name ?? this.name,
      cnic: cnic ?? this.cnic,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      userType: userType ?? this.userType,
      emailVerified: emailVerified ?? this.emailVerified,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      isApproved: isApproved ?? this.isApproved,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      carModel: carModel ?? this.carModel,
      carRegistration: carRegistration ?? this.carRegistration,
      seatsAvailable: seatsAvailable ?? this.seatsAvailable,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}