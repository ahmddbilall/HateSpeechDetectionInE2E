// lib/utils/model_encryption.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class ModelEncryption {
  static final _storage = FlutterSecureStorage();

  static Future<void> saveEncryptionKey(String key) async {
    await _storage.delete(key: 'modelEncryptionKey');
    await _storage.write(key: 'modelEncryptionKey', value: key);
  }

  static Future<String?> getEncryptionKey() async {
    return await _storage.read(key: 'modelEncryptionKey');
  }

  // static Future<String> decryptModel() async {
  // try {
  //   // ✅ Step 1: Check if already decrypted model exists
  //   final appDir = await getApplicationDocumentsDirectory();
  //   final cachedPath = '${appDir.path}/bert_cached_model.tflite';
  //   final cachedFile = File(cachedPath);
  //
  //   if (await cachedFile.exists()) {
  //     log('✅ Using cached decrypted model');
  //     // return cachedPath;
  //   }
  //
  //   log('🔐 No cached model found, decrypting...');
  //
  //   // Load encrypted model and IV from assets
  //   final encryptedData = await rootBundle.load('assets/model_encrypted.bin');
  //   final encryptedBytes = encryptedData.buffer.asUint8List();
  //   final ivData = await rootBundle.load('assets/encryption_iv.bin');
  //   final ivBytes = ivData.buffer.asUint8List();
  //
  //   if (ivBytes.length != 16) throw Exception('Invalid IV length');
  //
  //   final keyString = await getEncryptionKey();
  //   if (keyString == null) throw Exception('Encryption key not found');
  //
  //   final keyBytes = base64Decode(keyString);
  //   if (keyBytes.length != 16) throw Exception('Invalid key length');
  //
  //   // Decrypt
  //   final key = Key(keyBytes);
  //   final iv = IV(ivBytes);
  //   final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  //   final decrypted = encrypter.decryptBytes(Encrypted(encryptedBytes), iv: iv);
  //   log('✅ Decryption successful');
  //
  //   // SHA-256 check (optional, can comment out if confident in encryption)
  //   final hash = base64Encode(sha256.convert(decrypted).bytes);
  //   const expectedHash = 'bXPW7Bt/0+I0PSOnUPUw+95Em+ltApbbwgTGOi7xL7o=';
  //   if (hash != expectedHash) throw Exception('Model integrity check failed');
  //   log('✅ SHA-256 hash verified');
  //
  //   // ✅ Step 2: Save decrypted model to permanent location
  //   await cachedFile.writeAsBytes(decrypted);
  //   log('📁 Model saved at: $cachedPath');
  //
  //   return cachedPath;
  // } catch (e) {
  //   log('❌ Decryption failed: $e');
  //   rethrow;
  // }
  // }

  static Future<String> decryptModel() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cachedPath = '${appDir.path}/bert_cached_model.tflite';
      final cachedFile = File(cachedPath);

      if (await cachedFile.exists()) {
        log('✅ Using cached model');
        return cachedPath;
      }

      log('📁 Copying model from assets...');

      try {
        // Load unencrypted model file directly from assets
        final modelAsset = await rootBundle.load('assets/model.tflite');
        final modelBytes = modelAsset.buffer.asUint8List();

        log('📁 Found model in assets, size: ${modelBytes.length} bytes');

        // Write model to the cache location
        await cachedFile.writeAsBytes(modelBytes, flush: true);

        log('✅ Model copied successfully');
        log('📁 Model saved at: $cachedPath');

        return cachedPath;
      } catch (e) {
        log('❌ Error copying model from assets: $e');
        rethrow;
      }
    } catch (e) {
      log('❌ Model preparation failed: $e');
      rethrow;
    }
  }
}
