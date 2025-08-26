import 'package:flutter/material.dart';
import 'package:ride_share_app/screens/admin/user_list_screen.dart';
import 'package:ride_share_app/screens/admin/settings_screen.dart';
import 'package:ride_share_app/constants/colors.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.people, color: AppColors.primaryColor),
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
                leading: const Icon(Icons.drive_eta, color: AppColors.primaryColor),
                title: const Text('Manage Rides'),
                subtitle: const Text('(View all posted rides)'),
                onTap: () {
                  // The DriverHomeScreen is used as a combined view for admins
                  // This is a temporary setup until a dedicated admin ride view is built
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: ListTile(
                leading: const Icon(Icons.settings, color: AppColors.primaryColor),
                title: const Text('App Settings'),
                subtitle: const Text('Set commission rate, etc.'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
