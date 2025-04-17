import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_app/core/services/encryption_service.dart';

class DatabaseService {
  final _fire = FirebaseFirestore.instance;
  final _encryptionService = EncryptionService();

  Future<void> saveUser(Map<String, dynamic> userData) async {
    try {
      // Get the user's public key and add it to userData
      final publicKey = _encryptionService.getPublicKeyAsPem();
      if (publicKey != null) {
        userData['publicKey'] = publicKey;
      }
      
      await _fire.collection("users").doc(userData["uid"]).set(userData);

      log("User saved successfully with public key");
    } catch (e) {
      log("Error saving user: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> loadUser(String uid) async {
    try {
      final res = await _fire.collection("users").doc(uid).get();

      if (res.data() != null) {
        log("User fetched successfully");
        final userData = res.data();
        
        // If the user doesn't have a public key yet, update it
        if (userData != null && userData['publicKey'] == null) {
          final publicKey = _encryptionService.getPublicKeyAsPem();
          if (publicKey != null) {
            await _fire.collection("users").doc(uid).update({'publicKey': publicKey});
            userData['publicKey'] = publicKey;
          }
        }
        
        return userData;
      }
    } catch (e) {
      log("Error loading user: $e");
      rethrow;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> fetchUsers(String currentUserId) async {
    try {
      final res = await _fire
          .collection("users")
          .where("uid", isNotEqualTo: currentUserId)
          .get();

      return res.docs.map((e) => e.data()).toList();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> fetchUserStream(
          String currentUserId) =>
      _fire
          .collection("users")
          .where("uid", isNotEqualTo: currentUserId)
          .snapshots();
}
