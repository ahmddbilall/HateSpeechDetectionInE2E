import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat_app/core/services/encryption_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _encryptionService = EncryptionService();

  Future<User?> signup(String email, String password) async {
    try {
      final authCredential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      if (authCredential.user != null) {
        log("User created successfully");
        
        // Generate encryption keys for the new user
        await _encryptionService.generateKeyPair();
        
        return authCredential.user!;
      }
    } on FirebaseAuthException catch (e) {
      log(e.message!);
      rethrow;
    } catch (e) {
      log(e.toString());
      rethrow;
    }
    return null;
  }

  Future login(String email, String password) async {
    try {
      final authCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      if (authCredential.user != null) {
        log("User loggedin successfully");
        
        // Load encryption keys for the user if they exist
        final keysLoaded = await _encryptionService.loadKeys();
        if (!keysLoaded) {
          log("No encryption keys found for user, generating new ones");
          await _encryptionService.generateKeyPair();
        }
        
        return authCredential.user!;
      }
    } on FirebaseAuthException catch (e) {
      log(e.message!);
      rethrow;
    } catch (e) {
      log(e.toString());
      rethrow;
    }
    return null;
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      log(e.toString());
      rethrow;
    }
  }
}
