import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_app/core/models/message_model.dart';
import 'package:chat_app/core/services/encryption_service.dart';
import 'package:chat_app/core/services/key_exchange_service.dart';

class ChatService {
  final _fire = FirebaseFirestore.instance;
  final _encryptionService = EncryptionService();
  final _keyExchangeService = KeyExchangeService();

  Future<void> saveMessage(Map<String, dynamic> messageData, String chatRoomId, String recipientId, String? recipientPublicKey) async {
    try {
      // If recipient's public key is not provided, try to fetch it using the key exchange service
      if (recipientPublicKey == null) {
        log('Recipient public key not provided, attempting to fetch using KeyExchangeService');
        recipientPublicKey = await _keyExchangeService.getPublicKeyForUser(recipientId);
        
        if (recipientPublicKey == null) {
          // If still no public key, fallback to unencrypted message
          log('Warning: Recipient public key not available. Sending unencrypted message.');
          await _fire
              .collection("chatRooms")
              .doc(chatRoomId)
              .collection("messages")
              .add(messageData);
          return;
        } else {
          log('Successfully retrieved recipient public key');
        }
      }

      // Get the original message content
      final messageContent = messageData['content'] as String?;
      if (messageContent == null || messageContent.isEmpty) {
        throw Exception('Message content cannot be empty');
      }

      // Encrypt the message
      final encryptedData = await _encryptionService.encryptMessage(
        messageContent,
        recipientId,
        recipientPublicKey,
      );

      // Create a new message with encrypted content
      final encryptedMessage = Message(
        id: messageData['id'] as String?,
        content: null, // No plaintext content stored
        encryptedContent: encryptedData['encryptedMessage'],
        encryptedKey: encryptedData['encryptedKey'],
        iv: encryptedData['iv'],
        isEncrypted: true,
        senderId: messageData['senderId'] as String?,
        receiverId: messageData['receiverId'] as String?,
        timestamp: messageData['timestamp'] != null
            ? DateTime.fromMillisecondsSinceEpoch(messageData['timestamp'] as int)
            : DateTime.now(),
      );

      // Save the encrypted message
      await _fire
          .collection("chatRooms")
          .doc(chatRoomId)
          .collection("messages")
          .add(encryptedMessage.toMap());
    } catch (e) {
      log('Error encrypting/saving message: $e');
      rethrow;
    }
  }

  // Update the last message for both sender and receiver with encryption
  Future<void> updateLastMessage(String currentUid, String receiverUid, String message,
      int timestamp) async {
    try {
      log('Updating last message with encryption');
      
      // Try to get receiver's public key for encryption
      String? receiverPublicKey = await _keyExchangeService.getPublicKeyForUser(receiverUid);
      String? senderPublicKey = await _keyExchangeService.getPublicKeyForUser(currentUid);
      
      // Create encrypted version of the message for both users
      Map<String, dynamic> senderLastMessage;
      Map<String, dynamic> receiverLastMessage;
      
      // For sender's last message (encrypted with sender's key)
      if (senderPublicKey != null) {
        try {
          final encryptedData = await _encryptionService.encryptMessage(
            message,
            currentUid,
            senderPublicKey,
          );
          
          senderLastMessage = {
            "content": null,
            "encryptedContent": encryptedData['encryptedMessage'],
            "encryptedKey": encryptedData['encryptedKey'],
            "iv": encryptedData['iv'],
            "isEncrypted": true,
            "timestamp": timestamp,
            "senderId": currentUid
          };
        } catch (e) {
          log('Error encrypting last message for sender: $e');
          // Fallback to unencrypted if encryption fails
          senderLastMessage = {
            "content": message,
            "timestamp": timestamp,
            "senderId": currentUid,
            "isEncrypted": false
          };
        }
      } else {
        // No public key available, use unencrypted
        senderLastMessage = {
          "content": message,
          "timestamp": timestamp,
          "senderId": currentUid,
          "isEncrypted": false
        };
      }
      
      // For receiver's last message (encrypted with receiver's key)
      if (receiverPublicKey != null) {
        try {
          final encryptedData = await _encryptionService.encryptMessage(
            message,
            receiverUid,
            receiverPublicKey,
          );
          
          receiverLastMessage = {
            "content": null,
            "encryptedContent": encryptedData['encryptedMessage'],
            "encryptedKey": encryptedData['encryptedKey'],
            "iv": encryptedData['iv'],
            "isEncrypted": true,
            "timestamp": timestamp,
            "senderId": currentUid
          };
        } catch (e) {
          log('Error encrypting last message for receiver: $e');
          // Fallback to unencrypted if encryption fails
          receiverLastMessage = {
            "content": message,
            "timestamp": timestamp,
            "senderId": currentUid,
            "isEncrypted": false
          };
        }
      } else {
        // No public key available, use unencrypted
        receiverLastMessage = {
          "content": message,
          "timestamp": timestamp,
          "senderId": currentUid,
          "isEncrypted": false
        };
      }
      
      // Update the sender's document
      await _fire.collection("users").doc(currentUid).update({
        "lastMessage": senderLastMessage,
        "unreadCounter": FieldValue.increment(1)
      });

      // Update the receiver's document
      await _fire.collection("users").doc(receiverUid).update({
        "lastMessage": receiverLastMessage,
        "unreadCounter": 0
      });
      
      log('Last message updated successfully with encryption');
    } catch (e) {
      log('Error updating last message: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(String chatRoomId) {
    return _fire
        .collection("chatRooms")
        .doc(chatRoomId)
        .collection("messages")
        .orderBy("timestamp", descending: false)
        .snapshots();
  }
  
  // Decrypt a message if it's encrypted
  Future<Message> decryptMessageIfNeeded(Message message) async {
    try {
      // If the message is not encrypted or doesn't have the necessary encryption data, return as is
      if (message.isEncrypted != true ||
          message.encryptedContent == null ||
          message.encryptedKey == null ||
          message.iv == null) {
        return message;
      }

      // Prepare the encrypted data for decryption and ensure all values are strings
      final encryptedData = {
        'encryptedMessage': message.encryptedContent!.toString(),
        'encryptedKey': message.encryptedKey!.toString(),
        'iv': message.iv!.toString(),
      };

      // Decrypt the message
      final decryptedContent = await _encryptionService.decryptMessage(encryptedData);

      // Return a new message with the decrypted content
      return Message(
        id: message.id,
        content: decryptedContent,
        encryptedContent: message.encryptedContent,
        encryptedKey: message.encryptedKey,
        iv: message.iv,
        isEncrypted: true,
        senderId: message.senderId,
        receiverId: message.receiverId,
        timestamp: message.timestamp,
      );
    } catch (e) {
      log('Error decrypting message: $e');
      // Return the original message if decryption fails
      return message;
    }
  }
}
