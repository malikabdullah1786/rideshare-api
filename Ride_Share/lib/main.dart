import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:provider/provider.dart';

import 'package:ride_share_app/firebase_options.dart';

import 'package:ride_share_app/providers/auth_provider.dart'; // Import AppAuthProvider
import 'package:ride_share_app/providers/settings_provider.dart';
import 'package:ride_share_app/screens/auth_screen.dart';

import 'package:ride_share_app/screens/home_screen.dart'; // Ensure this import is correct and present

import 'package:ride_share_app/widgets/loading_indicator.dart';



void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(

    options: DefaultFirebaseOptions.currentPlatform,

  );

  runApp(const MyApp());

}



class MyApp extends StatelessWidget {

  const MyApp({super.key});



  @override

  Widget build(BuildContext context) {

    return MultiProvider(

      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],

      child: MaterialApp(

        title: 'Ride Share App',

        debugShowCheckedModeBanner: false, // HERE: Set to false to remove the debug banner

        theme: ThemeData(

          primarySwatch: Colors.blue,

          visualDensity: VisualDensity.adaptivePlatformDensity,

          appBarTheme: const AppBarTheme(

            elevation: 0,

            centerTitle: true,

            foregroundColor: Colors.white,

          ),

          inputDecorationTheme: InputDecorationTheme(

            border: OutlineInputBorder(

              borderRadius: BorderRadius.circular(8),

            ),

            focusedBorder: OutlineInputBorder(

              borderRadius: BorderRadius.circular(8),

              borderSide: const BorderSide(color: Color(0xFF4285F4), width: 2),

            ),

            enabledBorder: OutlineInputBorder(

              borderRadius: BorderRadius.circular(8),

              borderSide: const BorderSide(color: Colors.grey, width: 1),

            ),

          ),

          elevatedButtonTheme: ElevatedButtonThemeData(

            style: ElevatedButton.styleFrom(

              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),

              shape: RoundedRectangleBorder(

                borderRadius: BorderRadius.circular(8),

              ),

              textStyle: const TextStyle(fontSize: 18),

            ),

          ),

        ),
        home: Builder( // ADD THIS Builder widget
          builder: (context) { // ADD THIS Builder widget
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: LoadingIndicator()),
                  );
                }
                if (snapshot.hasData) {
                  // MODIFIED: Defer loadExtendedUserData call using addPostFrameCallback
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final appAuthProvider = Provider.of<AppAuthProvider>(context, listen: false);
                    // Only load if not already loaded, to prevent unnecessary calls
                    if (appAuthProvider.appUser == null || appAuthProvider.databaseService.getCurrentUserId() == null) {
                      appAuthProvider.loadExtendedUserData(snapshot.data!.uid);
                    }
                  });
                  return const HomeScreen();
                } else {
                  return const AuthScreen();
                }
              },
            );
          }, // ADD THIS closing bracket for Builder
        ),


      ),

    );

  }

}