import 'dart:async';
import 'dart:developer';

import 'package:chat_app/core/models/message_model.dart';
import 'package:chat_app/core/models/user_model.dart';
import 'package:chat_app/core/other/base_viewmodel.dart';
import 'package:chat_app/core/services/chat_service.dart';
import 'package:chat_app/core/services/encryption_service.dart';
import 'package:chat_app/core/services/key_exchange_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../../utils/inference.dart';

class ChatViewmodel extends BaseViewmodel {
  final ChatService _chatService;
  final UserModel _currentUser;
  final UserModel _receiver;
  final _encryptionService = EncryptionService();
  final _keyExchangeService = KeyExchangeService();

  StreamSubscription? _subscription;
  bool _isDecrypting = false;

  ChatViewmodel(this._chatService, this._currentUser, this._receiver) {
    getChatRoom();
    _initializeEncryption();
  }
  
  // Initialize encryption and message stream
  Future<void> _initializeEncryption() async {
    // Set up message listener with decryption
    _subscription = _chatService.getMessages(chatRoomId).listen((messages) async {
      final encryptedMessages = messages.docs.map((e) => Message.fromMap(e.data())).toList();
      
      if (!_isDecrypting) {
        _isDecrypting = true;
        _messages = await _decryptMessages(encryptedMessages);
        _isDecrypting = false;
        notifyListeners();
      }
    });
  }
  
  // Decrypt all messages in the list
  Future<List<Message>> _decryptMessages(List<Message> encryptedMessages) async {
    final decryptedMessages = <Message>[];
    
    for (final message in encryptedMessages) {
      try {
        // Only attempt to decrypt if the message is marked as encrypted and has the required fields
        if (message.isEncrypted == true && 
            message.encryptedContent != null && 
            message.encryptedKey != null && 
            message.iv != null) {
          log('Attempting to decrypt message: ${message.id}');
          final decryptedMessage = await _chatService.decryptMessageIfNeeded(message);
          decryptedMessages.add(decryptedMessage);
        } else {
          // If not encrypted or missing required fields, add as is
          decryptedMessages.add(message);
        }
      } catch (e) {
        log('Error decrypting message: $e');
        // Add the original message if decryption fails
        decryptedMessages.add(message);
      }
    }
    
    return decryptedMessages;
  }

  String chatRoomId = "";

  final _messageController = TextEditingController();

  TextEditingController get controller => _messageController;

  List<Message> _messages = [];

  List<Message> get messages => _messages;

  getChatRoom() {
    if (_currentUser.uid.hashCode > _receiver.uid.hashCode) {
      chatRoomId = "${_currentUser.uid}_${_receiver.uid}";
    } else {
      chatRoomId = "${_receiver.uid}_${_currentUser.uid}";
    }
  }

  saveMessage() async {
    log("Send Message");
    try {
      if (_messageController.text.isEmpty) {
        throw Exception("Please enter some text");
      }
      // check hate speech here

      String result = await HateSpeechDetector.runHateSpeechDetection(_messageController.text);

      if (result != 'Neutral'){
        log('message cannot be sent as it contains hate speech');

      }
      else {
        final now = DateTime.now();

        // Create a message object with plaintext content initially
        final message = Message(
            id: now.millisecondsSinceEpoch.toString(),
            content: _messageController.text,
            senderId: _currentUser.uid,
            receiverId: _receiver.uid,
            timestamp: now);

        // Ensure our public key is published
        await _keyExchangeService.ensurePublicKeyIsPublished();

        // Get recipient's public key for encryption using the key exchange service
        String? recipientPublicKey = await _keyExchangeService
            .getPublicKeyForUser(_receiver.uid!);

        // Log encryption status
        if (recipientPublicKey != null) {
          log("Sending encrypted message with recipient's public key");
        } else {
          log(
              "Sending unencrypted message - recipient's public key not available");
        }

        // Send the message with encryption if possible
        await _chatService.saveMessage(
            message.toMap(),
            chatRoomId,
            _receiver.uid!,
            recipientPublicKey
        );

        // Update last message (this is shown in the chat list and isn't encrypted)
        final lastMessagePrefix = recipientPublicKey != null
            ? " "
            : ""; // Add lock emoji to indicate encryption
        _chatService.updateLastMessage(
            _currentUser.uid!,
            _receiver.uid!,
            "$lastMessagePrefix${_messageController.text}",
            now.millisecondsSinceEpoch
        );

        _messageController.clear();
      }
    } catch (e) {
      log("Error sending message: $e");
      rethrow;
    }
  }

  @override
  void dispose() {
    super.dispose();

    _subscription?.cancel();
  }
}
