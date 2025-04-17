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

  UserModel? get user => _currentUser;

  loadUser(String uid) async {
    try {
      final userData = await _db.loadUser(uid);

      if (userData != null) {
        _currentUser = UserModel.fromMap(userData);
        notifyListeners();
        
        // Ensure the user's public key is published to the database
        await _keyExchangeService.ensurePublicKeyIsPublished();
        log('User loaded and public key published');
      }
    } catch (e) {
      log('Error loading user: $e');
    }
  }

  clearUser() {
    _currentUser = null;
    notifyListeners();
  }
}
