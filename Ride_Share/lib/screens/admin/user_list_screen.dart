import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ride_share_app/models/user_model.dart';
import 'package:ride_share_app/providers/auth_provider.dart';
import 'package:ride_share_app/services/database_service.dart';

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve user: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: FutureBuilder<List<AppUser>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text('${user.email} - ${user.userType}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user.userType == 'driver' && !user.isApproved)
                      ElevatedButton(
                        onPressed: () => _approveUser(user.id),
                        child: const Text('Approve'),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement manage permissions logic
                      },
                      child: const Text('Permissions'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
