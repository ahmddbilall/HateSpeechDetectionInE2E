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

  static Future<String> decryptModel() async {
    try {
      // Load encrypted model and IV from assets
      final encryptedData = await rootBundle.load('assets/mobilebert_hate_speech_encrypted.bin');
      final encryptedBytes = encryptedData.buffer.asUint8List();
      final ivData = await rootBundle.load('assets/encryption_iv.bin');
      final ivBytes = ivData.buffer.asUint8List();

      // Verify IV length
      if (ivBytes.length != 16) {
        throw Exception('Invalid IV length: Expected 16 bytes, got ${ivBytes.length}');
      }
      log('IV Bytes: ${ivBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');

      // Get encryption key
      final keyString = await getEncryptionKey();
      if (keyString == null) throw Exception('Encryption key not found');
      log('Key String: $keyString');

      // Decode key (16 bytes for AES-128)
      final keyBytes = base64Decode(keyString);
      if (keyBytes.length != 16) {
        throw Exception('Invalid key length: Expected 16 bytes, got ${keyBytes.length}');
      }
      log('AES Key Length: ${keyBytes.length} bytes');

      // Decrypt
      final key = Key(keyBytes);
      final iv = IV(ivBytes);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decryptBytes(Encrypted(encryptedBytes), iv: iv);
      log('Decryption successful');

      // Write decrypted model to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/mobilebert_hate_speech.tflite';
      await File(tempPath).writeAsBytes(decrypted);
      log('Model written to: $tempPath');

      // Verify integrity with SHA-256
      final hash = base64Encode(sha256.convert(decrypted).bytes);
      const expectedHash = 'MIRIjNz4t64sJTNdFuULYaHl7rPsdneNTr67Ts1vwAM='; // Replace with new hash from Python
      if (hash != expectedHash) throw Exception('Model integrity check failed');
      log('SHA-256 hash verified');

      return tempPath;
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }
}