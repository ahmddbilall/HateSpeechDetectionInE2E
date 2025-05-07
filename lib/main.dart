import 'dart:developer';

import 'package:chat_app/core/services/database_service.dart';
import 'package:chat_app/core/utils/route_utils.dart';
import 'package:chat_app/firebase_options.dart';
import 'package:chat_app/ui/screens/other/user_provider.dart';
import 'package:chat_app/ui/screens/splash/splash_screen.dart';
import 'package:chat_app/utils/model_encryption.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

void main() async {
  // print("🔥 MAIN: App is starting"); // ✅ Debug print
  log("🔥 LOG: App is starting");   // ✅ Dart developer log
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Only needed once, but harmless on every boot
  await ModelEncryption.saveEncryptionKey('9Vu7P4qCcdjb745xMJxzgQ==');

  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      builder: (context, child) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider(DatabaseService())),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateRoute: RouteUtils.onGenerateRoute,
          home: SplashScreen(),
        ),
      ),
    );
  }
}
