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
      File modelFile = File(modelPath); // Convert String path to File
      if (!await modelFile.exists()) {
        throw Exception('Model file does not exist at $modelPath');
      }
      _interpreter = await Interpreter.fromFile(modelFile);
      _interpreter!.allocateTensors();
      _isModelLoaded = true;
    } catch (e) {
      throw Exception('Failed to load model: $e');
    }
  }

  static Future<String> runHateSpeechDetection(String text) async {
    try {
      await initModel();
      final tokenizer = MobileBertTokenizer();
      final inputs = await tokenizer.tokenize(text);

      // Workaround: Use first token due to [1, 1] input shape
      List<int> inputIds = [inputs['input_ids']![0]];
      List<int> attentionMask = [inputs['attention_mask']![0]];
      List<int> tokenTypeIds = [inputs['token_type_ids']![0]];

      // Prepare inputs (int32, shape [1, 1])
      Int32List inputIdsInt32 = Int32List.fromList(inputIds);
      Int32List attentionMaskInt32 = Int32List.fromList(attentionMask);
      Int32List tokenTypeIdsInt32 = Int32List.fromList(tokenTypeIds);

      List<Int32List> inputTensors = [
        inputIdsInt32,
        attentionMaskInt32,
        tokenTypeIdsInt32,
      ];

      // Prepare output tensor (int8, shape [1, 2])
      var outputTensor = Int8List(2);
      var outputTensors = {0: outputTensor};

      _interpreter!.runForMultipleInputs(inputTensors, outputTensors);

      // Dequantize output (scale=13.029571, zero_point=-128)
      List<double> logits =
          outputTensor.map((i) => (i + 128) * 13.029571).toList();
      return logits[0] > logits[1] ? 'Neutral' : 'Hostile';
    } catch (e) {
      throw Exception('Inference failed: $e');
    }
  }

  static void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
    _interpreter = null;
  }
}
