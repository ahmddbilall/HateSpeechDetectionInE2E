import 'dart:io';
import 'dart:isolate';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:chat_app/utils/model_encryption.dart';

class ModelService {
  static final ModelService _instance = ModelService._internal();
  factory ModelService() => _instance;
  ModelService._internal();

  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  static const int MAX_SEQUENCE_LENGTH = 128;
  static const String _cachedModelPath =
      '/data/user/0/com.example.chat_app/cache/mobilebert_hate_speech.tflite';

  Interpreter? get interpreter => _interpreter;
  bool get isModelLoaded => _isModelLoaded;
  int get maxSequenceLength => MAX_SEQUENCE_LENGTH;

  Future<void> loadModel() async {
    if (_isModelLoaded) return;

    try {
      // Check if cached model exists
      final cachedModel = File(_cachedModelPath);
      if (await cachedModel.exists()) {
        _interpreter = await Interpreter.fromFile(cachedModel);
        _isModelLoaded = true;
        return;
      }

      // If no cached model, decrypt and cache it in background
      await _decryptAndCacheModel();

      // Load the cached model
      _interpreter = await Interpreter.fromFile(cachedModel);
      _isModelLoaded = true;
    } catch (e) {
      throw Exception('Failed to load model: $e');
    }
  }

  Future<void> _decryptAndCacheModel() async {
    // Create a ReceivePort to receive the result from the isolate
    final receivePort = ReceivePort();

    // Spawn the isolate
    await Isolate.spawn(
      _decryptModelInBackground,
      receivePort.sendPort,
    );

    // Wait for the result from the isolate
    await receivePort.first;
  }

  static Future<void> _decryptModelInBackground(SendPort sendPort) async {
    try {
      // Decrypt the model
      String modelPath = await ModelEncryption.decryptModel();

      // Verify the model was decrypted successfully
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        throw Exception('Model file does not exist at $modelPath');
      }

      // Signal completion
      sendPort.send(true);
    } catch (e) {
      // Signal error
      sendPort.send(e);
    }
  }

  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
    _interpreter = null;
  }
}
