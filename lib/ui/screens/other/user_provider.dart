import 'dart:developer';

import 'package:chat_app/core/models/user_model.dart';
import 'package:chat_app/core/services/database_service.dart';
import 'package:chat_app/core/services/key_exchange_service.dart';
import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  final DatabaseService _db;
  final _keyExchangeService = KeyExchangeService();

  UserProvider(this._db);

  UserModel? _currentUser;
  bool _isLoading = true;

  UserModel? get user => _currentUser;
  bool get isLoading => _isLoading;

  Future<void> loadUser(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userData = await _db.loadUser(uid);

      if (userData != null) {
        _currentUser = UserModel.fromMap(userData);

        // Ensure the user's public key is published to the database
        await _keyExchangeService.ensurePublicKeyIsPublished();

        log('✅ User loaded and public key published');
      } else {
        log('⚠️ No user data found in database');
      }
    } catch (e) {
      log('❌ Error loading user: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }
}

