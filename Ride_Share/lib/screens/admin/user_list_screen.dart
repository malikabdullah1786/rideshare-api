import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ride_share_app/constants/colors.dart';
import 'package:ride_share_app/models/user_model.dart';
import 'package:ride_share_app/providers/auth_provider.dart';
import 'package:ride_share_app/services/database_service.dart';
import 'package:ride_share_app/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late Future<List<AppUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
  }

  Future<List<AppUser>> _fetchUsers() async {
    final dbService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
    final userMaps = await dbService.getAllUsers();
    return userMaps.map((map) => AppUser.fromMap(map)).toList();
  }

  Future<void> _approveUser(String userId) async {
    try {
      final dbService = Provider.of<AppAuthProvider>(context, listen: false).databaseService;
      await dbService.approveUser(userId);
      setState(() {
        _usersFuture = _fetchUsers();
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User approved successfully!'), backgroundColor: AppColors.secondaryColor));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to approve user: $e'), backgroundColor: AppColors.errorColor));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: FutureBuilder<List<AppUser>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _usersFuture = _fetchUsers();
              });
            },
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            radius: 30,
                            backgroundImage: user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
                                ? NetworkImage(user.profilePictureUrl!)
                                : null,
                            child: user.profilePictureUrl == null || user.profilePictureUrl!.isEmpty
                                ? const Icon(Icons.person, size: 30)
                                : null,
                          ),
                          title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(user.email),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Type: ${user.userType.toUpperCase()}', style: TextStyle(color: user.userType == 'admin' ? AppColors.secondaryColor : AppColors.textColor)),
                              Text('Phone: ${user.phone}'),
                              Text('CNIC: ${user.cnic}'),
                              Text('Address: ${user.address}'),
                              Text('Joined: ${DateFormat('MMM dd, yyyy').format(user.createdAt)}'),
                              Text('Email Verified: ${user.emailVerified ? 'Yes' : 'No'}', style: TextStyle(color: user.emailVerified ? Colors.green : Colors.red)),
                              Text('Profile Approved: ${user.isApproved ? 'Yes' : 'No'}', style: TextStyle(color: user.isApproved ? Colors.green : Colors.red)),
                            ],
                          ),
                        ),
                        if (user.userType == 'driver' && !user.isApproved)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: () => _approveUser(user.id),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryColor),
                                child: const Text('Approve Driver'),
                              ),
                            ),
                          ),
                      ],
                    ),
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
