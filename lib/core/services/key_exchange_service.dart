import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat_app/core/services/encryption_service.dart';

/// A service to handle key exchange between users for end-to-end encryption
class KeyExchangeService {
  // Singleton instance
  static final KeyExchangeService _instance = KeyExchangeService._internal();
  factory KeyExchangeService() => _instance;
  KeyExchangeService._internal();

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _encryptionService = EncryptionService();

  /// Ensures the current user's public key is stored in the database
  Future<void> ensurePublicKeyIsPublished() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        log('Cannot publish public key: No user is logged in');
        return;
      }

      // First, try to load keys from local storage
      final keysLoaded = await _encryptionService.loadKeys();
      if (!keysLoaded) {
        // If keys couldn't be loaded, generate new ones
        log('No encryption keys found, generating new ones');
        await _encryptionService.generateKeyPair();
      }

      // Get the public key
      final publicKey = _encryptionService.getPublicKeyAsPem();
      if (publicKey == null) {
        log('Failed to get public key');
        return;
      }

      // Update the user's public key in the database
      await _fire.collection('users').doc(currentUser.uid).update({
        'publicKey': publicKey,
      });
      
      log('Public key published successfully');
    } catch (e) {
      log('Error publishing public key: $e');
    }
  }

  /// Retrieves the public key for a specific user
  Future<String?> getPublicKeyForUser(String userId) async {
    try {
      final userDoc = await _fire.collection('users').doc(userId).get();
      
      if (userDoc.exists && userDoc.data() != null && userDoc.data()!['publicKey'] != null) {
        final publicKey = userDoc.data()!['publicKey'] as String;
        log('Retrieved public key for user $userId');
        return publicKey;
      }
      
      log('No public key found for user $userId');
      return null;
    } catch (e) {
      log('Error retrieving public key: $e');
      return null;
    }
  }
}
