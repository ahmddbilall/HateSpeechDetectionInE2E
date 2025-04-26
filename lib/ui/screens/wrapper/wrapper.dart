import 'dart:developer';
import 'package:chat_app/ui/screens/auth/login/login_screen.dart';
import 'package:chat_app/ui/screens/bottom_navigation/bottom_navigation_screen.dart';
import 'package:chat_app/ui/screens/other/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Wrapper extends StatefulWidget {
  const Wrapper({super.key});

  @override
  State<Wrapper> createState() => _WrapperState();
}

class _WrapperState extends State<Wrapper> {
  bool _hasLoadedUser = false;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text("Something went wrong!"));
        }

        final user = snapshot.data;

        if (user == null) {
          log("🚪 User is null — show login");
          return const LoginScreen();
        }

        // ✅ Load user into UserProvider (once)
        if (!_hasLoadedUser) {
          log("🧠 Authenticated, loading user data...");
          Provider.of<UserProvider>(context, listen: false).loadUser(user.uid);
          _hasLoadedUser = true;
        }

        // ✅ Wait until userProvider finishes loading the user
        if (userProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        log("✅ Auth + User loaded — show chat screen");
        return const BottomNavigationScreen();
      },
    );
  }
}



