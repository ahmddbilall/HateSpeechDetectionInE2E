import 'dart:convert';

class Message {
  final String? id;
  final String? content; // For plaintext content (when viewing decrypted messages)
  final String? encryptedContent; // Base64 encoded encrypted message
  final String? encryptedKey; // RSA encrypted AES key
  final String? iv; // Initialization vector for AES
  final bool? isEncrypted; // Flag to indicate if the message is encrypted
  final String? senderId;
  final String? receiverId;
  final DateTime? timestamp;

  Message({
    this.id,
    this.content,
    this.encryptedContent,
    this.encryptedKey,
    this.iv,
    this.isEncrypted = false,
    this.senderId,
    this.receiverId,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'content': isEncrypted == true ? null : content, // Only store plaintext if not encrypted
      'encryptedContent': encryptedContent,
      'encryptedKey': encryptedKey,
      'iv': iv,
      'isEncrypted': isEncrypted,
      'senderId': senderId,
      'receiverId': receiverId,
      'timestamp': timestamp?.millisecondsSinceEpoch,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] != null ? map['id'] as String : null,
      content: map['content'] != null ? map['content'] as String : null,
      encryptedContent: map['encryptedContent'] != null ? map['encryptedContent'] as String : null,
      encryptedKey: map['encryptedKey'] != null ? map['encryptedKey'] as String : null,
      iv: map['iv'] != null ? map['iv'] as String : null,
      isEncrypted: map['isEncrypted'] != null ? map['isEncrypted'] as bool : false,
      senderId: map['senderId'] != null ? map['senderId'] as String : null,
      receiverId:
          map['receiverId'] != null ? map['receiverId'] as String : null,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Message.fromJson(String source) =>
      Message.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'Message(id: $id, content: ${isEncrypted == true ? "[ENCRYPTED]" : content}, senderId: $senderId, receiverId: $receiverId, timestamp: $timestamp, isEncrypted: $isEncrypted)';
  }
}
