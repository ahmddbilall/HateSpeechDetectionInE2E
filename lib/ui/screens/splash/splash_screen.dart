import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:chat_app/core/constants/string.dart';
import 'package:chat_app/core/services/model_service.dart';
import 'package:chat_app/ui/screens/auth/login/login_screen.dart';
import 'package:chat_app/ui/screens/bottom_navigation/bottom_navigation_screen.dart';

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
      // Start loading the model in background
      final modelFuture = ModelService().loadModel();

      // Show initial UI
      setState(() {
        _loadingText = 'Initializing...';
      });

      // Wait for model to load
      await modelFuture;

      if (!mounted) return;

      // Check authentication
      final user = FirebaseAuth.instance.currentUser;

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => user != null
                ? const BottomNavigationScreen()
                : const LoginScreen(),
          ),
        );
      }
    } catch (e) {
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
