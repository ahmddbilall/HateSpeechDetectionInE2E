import 'dart:async';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'package:chat_app/core/constants/string.dart';
import 'package:chat_app/core/services/model_service.dart';
import 'package:chat_app/ui/screens/auth/login/login_screen.dart';
import 'package:chat_app/ui/screens/bottom_navigation/bottom_navigation_screen.dart';
import 'package:chat_app/ui/screens/other/user_provider.dart';
import 'package:chat_app/utils/inference.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _isLoading = true;
  String _loadingText = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      log('⚙️ Calling HateSpeechDetector.initModel...');
      await HateSpeechDetector.initModel();
      log('✅ Model loaded successfully');

      setState(() {
        _loadingText = 'Initializing...';
      });

      await ModelService().loadModel();

      if (!mounted) return;

      log('⏳ Waiting for Firebase auth state...');
      final user = await FirebaseAuth.instance.authStateChanges().first;

      if (!mounted) return;

      if (user != null) {
        log("✅ Firebase user detected: ${user.uid}");

        // ✅ Ensure UserProvider loads Firestore user data
        await Provider.of<UserProvider>(context, listen: false).loadUser(user.uid);
        log("✅ UserProvider finished loading user");
      } else {
        log("🚪 No Firebase user detected");
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              user != null ? const BottomNavigationScreen() : const LoginScreen(),
        ),
      );
    } catch (e) {
      log('❌ SplashScreen failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingText = 'Error: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            frame,
            height: 1.sh,
            width: 1.sw,
            fit: BoxFit.cover,
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  logo,
                  height: 170,
                  width: 170,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                const SizedBox(height: 10),
                Text(
                  _loadingText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



