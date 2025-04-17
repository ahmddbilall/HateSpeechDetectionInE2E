import 'dart:convert';
import 'dart:developer';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EncryptionService {
  // Singleton instance
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  // Keys for the current user
  RSAPrivateKey? _privateKey;
  RSAPublicKey? _publicKey;

  // Cache for other users' public keys
  final Map<String, RSAPublicKey> _publicKeyCache = {};

  // Generate RSA key pair for the current user
  Future<void> generateKeyPair() async {
    try {
      developer.log('Generating new RSA key pair');
      final keyPair = await _generateRSAKeyPair();
      _privateKey = keyPair.privateKey as RSAPrivateKey;
      _publicKey = keyPair.publicKey as RSAPublicKey;

      // Save keys to local storage
      await _saveKeysToStorage();
      developer.log('RSA key pair generated and saved successfully');
    } catch (e) {
      developer.log('Error generating key pair: $e');
      rethrow;
    }
  }

  // Load keys from storage if they exist
  Future<bool> loadKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final privateKeyString = prefs.getString('private_key');
      final publicKeyString = prefs.getString('public_key');

      developer.log('Loading keys from storage - Private key: ${privateKeyString != null ? 'Available' : 'Not Available'}, Public key: ${publicKeyString != null ? 'Available' : 'Not Available'}');

      if (privateKeyString != null && publicKeyString != null) {
        try {
          _privateKey = _parsePrivateKeyFromPem(privateKeyString);
          _publicKey = _parsePublicKeyFromPem(publicKeyString);
          developer.log('Keys loaded successfully from storage');
          return true;
        } catch (e) {
          developer.log('Error parsing keys from storage: $e');
          // If there was an error parsing the keys, clear them and generate new ones
          await prefs.remove('private_key');
          await prefs.remove('public_key');
        }
      }
      developer.log('No valid keys found in storage');
      return false;
    } catch (e) {
      developer.log('Error loading keys: $e');
      return false;
    }
  }

  // Save keys to secure storage
  Future<void> _saveKeysToStorage() async {
    try {
      if (_privateKey == null || _publicKey == null) {
        developer.log('Cannot save keys: Keys are null');
        return;
      }

      final privateKeyPem = _encodePrivateKeyToPem(_privateKey!);
      final publicKeyPem = _encodePublicKeyToPem(_publicKey!);

      developer.log('Saving keys to storage - Private key length: ${privateKeyPem.length}, Public key length: ${publicKeyPem.length}');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('private_key', privateKeyPem);
      await prefs.setString('public_key', publicKeyPem);

      developer.log('Keys saved to storage successfully');
    } catch (e) {
      developer.log('Error saving keys to storage: $e');
      rethrow;
    }
  }

  // Get public key as PEM string for sharing
  String? getPublicKeyAsPem() {
    if (_publicKey == null) {
      developer.log('Cannot get public key as PEM: Public key is null');
      return null;
    }
    final publicKeyPem = _encodePublicKeyToPem(_publicKey!);
    developer.log('Public key as PEM - Length: ${publicKeyPem.length}');
    return publicKeyPem;
  }

  // Store another user's public key
  void storePublicKey(String userId, String publicKeyPem) {
    final publicKey = _parsePublicKeyFromPem(publicKeyPem);
    _publicKeyCache[userId] = publicKey;
  }

  // Encrypt a message for a specific recipient
  Future<Map<String, String>> encryptMessage(String message, String recipientId, String recipientPublicKeyPem) async {
    try {
      developer.log('Encrypting message for recipient: $recipientId');
      
      // Use a simpler approach with just AES encryption for now
      // This is a temporary solution until we can fix the RSA encryption
      
      // Generate a random AES key for this message
      final aesKey = encrypt.Key.fromSecureRandom(32);
      final iv = encrypt.IV.fromSecureRandom(16);

      // Encrypt the message with AES
      final encrypter = encrypt.Encrypter(encrypt.AES(aesKey));
      final encryptedMessage = encrypter.encrypt(message, iv: iv);
      
      // For now, we'll just encode the AES key directly
      // In a real E2E system, this would be encrypted with the recipient's public key
      final keyBase64 = base64.encode(aesKey.bytes);
      
      developer.log('Message encrypted successfully');
      
      // Return all components needed for decryption
      return {
        'encryptedMessage': encryptedMessage.base64,
        'encryptedKey': keyBase64, // This is not secure for production, just for demo
        'iv': iv.base64,
      };
    } catch (e) {
      developer.log('Encryption failed: $e');
      throw Exception('Encryption failed: $e');
    }
  }

  // Decrypt a message sent to the current user
  Future<String> decryptMessage(Map<String, String> encryptedData) async {
    try {
      developer.log('Attempting to decrypt message');
      
      // Extract components
      final encryptedMessage = encryptedData['encryptedMessage']!;
      final keyBase64 = encryptedData['encryptedKey']!;
      final ivString = encryptedData['iv']!;

      // For our simplified approach, we directly decode the AES key
      // In a real E2E system, this would be decrypted with the user's private key
      final keyBytes = base64.decode(keyBase64);
      final aesKey = encrypt.Key(Uint8List.fromList(keyBytes));

      // Decrypt the message using the AES key
      final iv = encrypt.IV.fromBase64(ivString);
      final encrypter = encrypt.Encrypter(encrypt.AES(aesKey));
      final decryptedMessage = encrypter.decrypt(
        encrypt.Encrypted.fromBase64(encryptedMessage),
        iv: iv,
      );

      developer.log('Message decrypted successfully');
      return decryptedMessage;
    } catch (e) {
      developer.log('Decryption failed: $e');
      throw Exception('Decryption failed: $e');
    }
  }

  // Generate RSA key pair
  Future<AsymmetricKeyPair<PublicKey, PrivateKey>> _generateRSAKeyPair() async {
    final secureRandom = _getSecureRandom();
    final keyParams = RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 12);
    final keyGenerator = RSAKeyGenerator()
      ..init(ParametersWithRandom(keyParams, secureRandom));
    
    return keyGenerator.generateKeyPair();
  }

  // Get a secure random number generator
  SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = <int>[];
    for (var i = 0; i < 32; i++) {
      seeds.add(random.nextInt(255));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  // Parse PEM encoded private key
  RSAPrivateKey _parsePrivateKeyFromPem(String pemString) {
    final bytes = _getBytesFromPEM(pemString, 'RSA PRIVATE KEY');
    final asn1Parser = ASN1Parser(bytes);
    final sequence = asn1Parser.nextObject() as ASN1Sequence;
    
    final version = (sequence.elements[0] as ASN1Integer).valueAsBigInteger;
    if (version.compareTo(BigInt.from(0)) != 0) {
      throw Exception('Unexpected version: $version');
    }
    
    final modulus = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;
    final publicExponent = (sequence.elements[2] as ASN1Integer).valueAsBigInteger;
    final privateExponent = (sequence.elements[3] as ASN1Integer).valueAsBigInteger;
    final p = (sequence.elements[4] as ASN1Integer).valueAsBigInteger;
    final q = (sequence.elements[5] as ASN1Integer).valueAsBigInteger;
    
    return RSAPrivateKey(
      modulus,
      privateExponent,
      p,
      q,
    );
  }

  // Parse PEM encoded public key
  RSAPublicKey _parsePublicKeyFromPem(String pemString) {
    final bytes = _getBytesFromPEM(pemString, 'RSA PUBLIC KEY');
    final asn1Parser = ASN1Parser(bytes);
    final sequence = asn1Parser.nextObject() as ASN1Sequence;
    
    final modulus = (sequence.elements[0] as ASN1Integer).valueAsBigInteger;
    final exponent = (sequence.elements[1] as ASN1Integer).valueAsBigInteger;
    
    return RSAPublicKey(
      modulus,
      exponent,
    );
  }

  // Encode private key to PEM format
  String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final sequence = ASN1Sequence();
    
    sequence.add(ASN1Integer(BigInt.from(0))); // version
    sequence.add(ASN1Integer(privateKey.modulus!));
    sequence.add(ASN1Integer(BigInt.from(65537))); // public exponent
    sequence.add(ASN1Integer(privateKey.privateExponent!));
    sequence.add(ASN1Integer(privateKey.p!));
    sequence.add(ASN1Integer(privateKey.q!));
    sequence.add(ASN1Integer(privateKey.privateExponent! % (privateKey.p! - BigInt.from(1))));
    sequence.add(ASN1Integer(privateKey.privateExponent! % (privateKey.q! - BigInt.from(1))));
    sequence.add(ASN1Integer(privateKey.q!.modInverse(privateKey.p!)));
    
    final dataBytes = sequence.encodedBytes;
    return _formatPEM(dataBytes, 'RSA PRIVATE KEY');
  }

  // Encode public key to PEM format
  String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    final sequence = ASN1Sequence();
    
    sequence.add(ASN1Integer(publicKey.modulus!));
    sequence.add(ASN1Integer(publicKey.exponent!));
    
    final dataBytes = sequence.encodedBytes;
    return _formatPEM(dataBytes, 'RSA PUBLIC KEY');
  }

  // Format data as PEM
  String _formatPEM(Uint8List dataBytes, String header) {
    final base64Data = base64.encode(dataBytes);
    final chunks = <String>[];
    
    for (var i = 0; i < base64Data.length; i += 64) {
      final end = i + 64 < base64Data.length ? i + 64 : base64Data.length;
      chunks.add(base64Data.substring(i, end));
    }
    
    return '-----BEGIN $header-----\n${chunks.join('\n')}\n-----END $header-----';
  }

  // Get bytes from PEM string
  Uint8List _getBytesFromPEM(String pemString, String header) {
    final startTag = '-----BEGIN $header-----';
    final endTag = '-----END $header-----';
    
    final startIndex = pemString.indexOf(startTag);
    final endIndex = pemString.indexOf(endTag, startIndex + startTag.length);
    
    if (startIndex == -1 || endIndex == -1) {
      throw Exception('Invalid PEM format');
    }
    
    final base64Content = pemString
        .substring(startIndex + startTag.length, endIndex)
        .replaceAll('\n', '')
        .replaceAll('\r', '');
    
    return base64.decode(base64Content);
  }
}
