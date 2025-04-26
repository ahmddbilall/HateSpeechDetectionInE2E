import 'dart:developer';
import 'package:chat_app/core/enums/enums.dart';
import 'package:chat_app/core/other/base_viewmodel.dart';
import 'package:chat_app/core/services/auth_service.dart';
import 'package:chat_app/core/services/database_service.dart';
import 'package:chat_app/core/services/encryption_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:chat_app/core/constants/string.dart'; // ✅ For 'wrapper' route

class LoginViewmodel extends BaseViewmodel {
  final AuthService _auth;
  final _encryptionService = EncryptionService();
  final _databaseService = DatabaseService();
  final _fire = FirebaseFirestore.instance;

  LoginViewmodel(this._auth);

  String _email = '';
  String _password = '';

  void setEmail(String value) {
    _email = value;
    notifyListeners();
    log("Email: $_email");
  }

  void setPassword(String value) {
    _password = value;
    notifyListeners();
    log("Password: $_password");
  }

  Future<void> login(BuildContext context) async {
    setstate(ViewState.loading);
    try {
      final user = await _auth.login(_email, _password);

      if (user != null) {
        final keysLoaded = await _encryptionService.loadKeys();
        log("Encryption keys loaded: $keysLoaded");

        if (!keysLoaded) {
          log("Generating new encryption keys");
          await _encryptionService.generateKeyPair();

          final publicKey = _encryptionService.getPublicKeyAsPem();
          if (publicKey != null) {
            log("Updating user with new public key");
            final userData = await _databaseService.loadUser(user.uid);
            if (userData != null) {
              await _fire.collection("users").doc(user.uid).update({'publicKey': publicKey});
            }
          }
        }

        // ✅ Navigate to main app screen (Wrapper)
        Navigator.pushReplacementNamed(context, wrapper);
      }

      setstate(ViewState.idle);
    } on FirebaseAuthException catch (e) {
      setstate(ViewState.idle);
      rethrow;
    } catch (e) {
      log("Error during login: $e");
      setstate(ViewState.idle);
      rethrow;
    }
  }
}

