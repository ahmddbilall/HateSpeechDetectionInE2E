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
  UserModel get currentUser => _currentUser;

  StreamSubscription? _subscription;
  bool _isDecrypting = false;

  ChatViewmodel(this._chatService, this._currentUser, this._receiver) {
    log("🚀 ChatViewmodel initialized");
    log("👤 currentUser UID: ${_currentUser.uid}");
    log("📨 receiver UID: ${_receiver.uid}");
    getChatRoom();
    _initializeEncryption();
  }

  Future<void> _initializeEncryption() async {
    log("🔐 Initializing encrypted chat listener...");
    _subscription = _chatService.getMessages(chatRoomId).listen((messages) async {
      final encryptedMessages = messages.docs.map((e) => Message.fromMap(e.data())).toList();

      if (!_isDecrypting) {
        log("🔓 Decrypting incoming messages...");
        _isDecrypting = true;
        _messages = await _decryptMessages(encryptedMessages);
        _isDecrypting = false;
        notifyListeners();
      }
    });
  }

  Future<List<Message>> _decryptMessages(List<Message> encryptedMessages) async {
    final decryptedMessages = <Message>[];

    for (final message in encryptedMessages) {
      try {
        if (message.isEncrypted == true && message.encryptedContent != null && message.encryptedKey != null && message.iv != null) {
          log("🔐 Decrypting message: ${message.id}");
          final decryptedMessage = await _chatService.decryptMessageIfNeeded(message);
          decryptedMessages.add(decryptedMessage);
        } else {
          log("📥 Plain message detected or incomplete encryption fields.");
          decryptedMessages.add(message);
        }
      } catch (e) {
        log("❌ Error decrypting message: ${message.id} — $e");
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
    chatRoomId = (_currentUser.uid.hashCode > _receiver.uid.hashCode)
        ? "${_currentUser.uid}_${_receiver.uid}"
        : "${_receiver.uid}_${_currentUser.uid}";
    log("💬 ChatRoom ID set: $chatRoomId");
  }

  saveMessage(BuildContext context) async {
    log("📤 saveMessage called");

    try {
      final text = _messageController.text.trim();
      _messageController.clear();
      log("🟢 User input: '$text'");

      if (text.isEmpty) {
        log("⚠️ Message is empty, ignoring.");
        return;
      }

      log("🧠 Running hate speech detection...");
      final result = await HateSpeechDetector.runHateSpeechDetection(text);
      log("🧠 Detection result: $result");

      if (result['result'] != 'Neutral') {
        log("🚫 Hate speech detected — message blocked");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Message can't be sent due to hate speech detection."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }


      final now = DateTime.now();
      final message = Message(
        id: now.millisecondsSinceEpoch.toString(),
        content: text,
        senderId: _currentUser.uid,
        receiverId: _receiver.uid,
        timestamp: now,
      );

      log("📡 Publishing current user's public key...");
      await _keyExchangeService.ensurePublicKeyIsPublished();

      String? recipientPublicKey =
          await _keyExchangeService.getPublicKeyForUser(_receiver.uid!);

      if (recipientPublicKey != null) {
        log("🔐 Recipient public key retrieved");
      } else {
        log("⚠️ No recipient public key found — sending plain message");
      }

      log("💾 Saving message...");
      await _chatService.saveMessage(
        message.toMap(),
        chatRoomId,
        _receiver.uid!,
        recipientPublicKey,
      );

      final lastMessagePrefix = recipientPublicKey != null ? " " : "";
      await _chatService.updateLastMessage(
        _currentUser.uid!,
        _receiver.uid!,
        "$lastMessagePrefix$text",
        now.millisecondsSinceEpoch,
      );

      _messageController.clear();
      log("✅ Message sent and input cleared.");
    } catch (e, st) {
      log("❌ Exception during saveMessage: $e");
      log("📍 StackTrace: $st");
    }
  }

  @override
  void dispose() {
    super.dispose();
    log("🧹 Disposing ChatViewmodel and cancelling subscriptions");
    _subscription?.cancel();
  }


}