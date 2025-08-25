import 'package:flutter/material.dart';
import 'package:ride_share_app/screens/admin/user_list_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Manage Users'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserListScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.drive_eta),
                title: const Text('Manage Rides'),
                onTap: () {
                  // Navigate to ride management screen
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
