// lib/utils/inference.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:chat_app/utils/tokenizer.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'model_encryption.dart';

class HateSpeechDetector {
  static Interpreter? _interpreter;
  static bool _isModelLoaded = false;

  static Future<void> initModel() async {
    if (_isModelLoaded) return;
    try {
      String modelPath = await ModelEncryption.decryptModel();
      print('📍 TFLite loading model from: $modelPath');
      File modelFile = File(modelPath);

      if (!await modelFile.exists()) {
        throw Exception('Model file does not exist at $modelPath');
      }
      _interpreter = await Interpreter.fromFile(modelFile);
      _interpreter!.allocateTensors();
      _isModelLoaded = true;
    } catch (e) {
      print('❌ Model loading failed: $e');
      rethrow;

    }
  }

  static Future<String> runHateSpeechDetection(String text) async {
  try {
    await initModel();
    final tokenizer = MobileBertTokenizer();
    final inputs = await tokenizer.tokenize(text);

    const int maxLen = 128;

    // Extract and pad
    List<int> inputIds = _padOrTruncate(inputs['input_ids']!, maxLen);
    List<int> attentionMask = _padOrTruncate(inputs['attention_mask']!, maxLen);
    List<int> tokenTypeIds = _padOrTruncate(inputs['token_type_ids']!, maxLen);

    // Shape [1, 128]
    List<List<int>> inputTensor = [inputIds];
    List<List<int>> attentionMaskTensor = [attentionMask];
    List<List<int>> tokenTypeTensor = [tokenTypeIds];

    //  Output tensor with correct shape: [1, 2]
    List<List<double>> outputTensor = List.generate(1, (_) => List.filled(2, 0.0));

    _interpreter!.runForMultipleInputs(
      [inputTensor, attentionMaskTensor, tokenTypeTensor],
      {0: outputTensor},
    );

    // Flatten [1, 2] → [2]
    List<double> raw = outputTensor[0];

    // Dequantize
    List<double> logits =
        raw.map((i) => (i + 128) * 13.029571).toList();

    return logits[0] > logits[1] ? 'Neutral' : 'Hostile';
  } catch (e) {
    throw Exception('Inference failed: $e');
  }
}


// Helper to pad or truncate to length 128
static List<int> _padOrTruncate(List<int> input, int length) {
  if (input.length > length) {
    return input.sublist(0, length);
  } else if (input.length < length) {
    return input + List.filled(length - input.length, 0);
  } else {
    return input;
  }
}


  static void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
    _interpreter = null;
  }
}
