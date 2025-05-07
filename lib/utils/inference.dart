// lib/utils/inference.dart
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'package:chat_app/utils/tokenizer.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'model_encryption.dart';

class HateSpeechDetector {
  static Interpreter? _interpreter;
  static bool _isModelLoaded = false;
  static List<List<int>>? _inputShapes;
  static List<List<int>>? _outputShapes;


  static void debugModelInfo() {
    if (_interpreter == null || !_isModelLoaded) {
      log('⚠️ Cannot debug model - not loaded yet');
      return;
    }

    try {
      var inputTensors = _interpreter!.getInputTensors();
      var outputTensors = _interpreter!.getOutputTensors();

      log('📝 === MODEL DEBUG INFO ===');
      log('📝 Model has ${inputTensors.length} input tensors:');
      for (var i = 0; i < inputTensors.length; i++) {
        log('📝 Input $i: name=${inputTensors[i].name}, shape=${inputTensors[i].shape}, type=${inputTensors[i].type}');
      }

      log('📝 Model has ${outputTensors.length} output tensors:');
      for (var i = 0; i < outputTensors.length; i++) {
        log('📝 Output $i: name=${outputTensors[i].name}, shape=${outputTensors[i].shape}, type=${outputTensors[i].type}');
      }


      log('📝 === END MODEL DEBUG ===');
    } catch (e) {
      log('❌ Error debugging model: $e');
    }
  }

  static Future<void> initModel() async {
    if (_isModelLoaded) return;
    try {
      String modelPath = await ModelEncryption.decryptModel();
      print('📍 TFLite loading model from: $modelPath');
      File modelFile = File(modelPath);

      if (!await modelFile.exists()) {
        throw Exception('Model file does not exist at $modelPath');
      }

      // Create interpreter options with proper settings
      final interpreterOptions = InterpreterOptions()..threads = 2;

      _interpreter = await Interpreter.fromFile(modelFile, options: interpreterOptions);

      // 1) resize each of the three inputs to [1, 128]
      for (int i = 0; i < 3; i++) {
        _interpreter!.resizeInputTensor(i, [1, 128]);
      }

      _interpreter!.allocateTensors();


      // Get input and output tensor details
      var inputTensors = _interpreter!.getInputTensors();
      var outputTensors = _interpreter!.getOutputTensors();

      // Store the shapes for later use
      _inputShapes = inputTensors.map((tensor) => tensor.shape).toList();
      _outputShapes = outputTensors.map((tensor) => tensor.shape).toList();

      print('📊 Model input tensors: ${inputTensors.length}');
      for (var i = 0; i < inputTensors.length; i++) {
        print('Input $i shape: ${inputTensors[i].shape}, type: ${inputTensors[i].type}, name: ${inputTensors[i].name}');
      }

      print('📊 Model output tensors: ${outputTensors.length}');
      for (var i = 0; i < outputTensors.length; i++) {
        print('Output $i shape: ${outputTensors[i].shape}, type: ${outputTensors[i].type}, name: ${outputTensors[i].name}');
      }

      _isModelLoaded = true;
      debugModelInfo(); // Print detailed model info

    } catch (e) {
      print('❌ Model loading failed: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> runHateSpeechDetection(String text) async {
    try {
      await initModel();
      debugModelInfo();

      // Guard against empty or very short input
      if (text.trim().isEmpty || text.trim().length <= 1) {
        // Return neutral for very short/empty text
        return {
          'result': 'Neutral',
          'confidence': 1.0,
          'probabilities': [1.0, 0.0],
          'logits': [0.0, -10.0], // Arbitrary values strongly favoring neutral
          'note': 'Input too short for reliable prediction'
        };
      }

      final tokenizer = MobileBertTokenizer();
      final inputs = await tokenizer.tokenize(text);

      // Debug: Print tokenized input
      log('🔤 Tokenized input: ${inputs['input_ids']!.length} tokens');
      log('🔤 First few tokens: ${inputs['input_ids']!.take(10).toList()}');

      const int maxLen = 128;

      // Extract and pad
      List<int> inputIds = _padOrTruncate(inputs['input_ids']!, maxLen);
      List<int> attentionMask = _padOrTruncate(inputs['attention_mask']!, maxLen);
      List<int> tokenTypeIds = _padOrTruncate(inputs['token_type_ids']!, maxLen);

      // Debug: Print shapes to verify
      log('📐 inputIds shape: ${inputIds.length}');
      log('📐 attentionMask shape: ${attentionMask.length}');
      log('📐 tokenTypeIds shape: ${tokenTypeIds.length}');

      // Check if we need to reshape inputs based on model expectations
      bool needReshape = _inputShapes != null &&
          _inputShapes!.isNotEmpty &&
          _inputShapes![0].length >= 2 &&
          _inputShapes![0][1] != maxLen;

      List<Object> inputTensors;
      log('Input shape: $_inputShapes');
      log('Need reshape: $needReshape');
      if (needReshape) {
        // Model expects a different input shape
        log('⚠️ Reshaping inputs to match expected model shape: ${_inputShapes![0]}');

        // Try to resize tensor inputs dynamically
        try {
          await _resizeTensorInputs(text);
          inputTensors = [
            [inputIds],
            [attentionMask],
            [tokenTypeIds]
          ];
        } catch (e) {
          log('❌ Dynamic resizing failed: $e');
          // Use the fixed expected shape from model
          int expectedLen = _inputShapes![0][1];
          inputTensors = [
            [_padOrTruncate(inputs['input_ids']!, expectedLen)],
            [_padOrTruncate(inputs['attention_mask']!, expectedLen)],
            [_padOrTruncate(inputs['token_type_ids']!, expectedLen)]
          ];
        }
      } else {
        // Use standard shape [1, maxLen]
        inputTensors = [
          [inputIds],
          [attentionMask],
          [tokenTypeIds]
        ];
      }

      // Prepare output tensor with shape [1, 2]
      var outputTensors = [
        List.generate(1, (_) => List<double>.filled(2, 0))
      ];

      // Verify input order matches what the model expects
      bool hasTensorsInfo = false;
      try {
        var inputDetails = _interpreter!.getInputTensors();
        hasTensorsInfo = inputDetails.isNotEmpty;
        log('Input details: $inputDetails');
        if (hasTensorsInfo) {
          List<Object> reorderedInputs = List.filled(inputDetails.length, []);
          for (var i = 0; i < inputDetails.length; i++) {
            String name = inputDetails[i].name;
            if (name.contains("input_ids")) {
              reorderedInputs[i] = inputTensors[1]; // input_ids
            } else if (name.contains("attention_mask")) {
              reorderedInputs[i] = inputTensors[0]; // attention_mask
            } else if (name.contains("token_type")) {
              reorderedInputs[i] = inputTensors[2]; // token_type_ids
            }
          }
          // Replace with reordered inputs if successful
          if (!reorderedInputs.contains([])) {
            inputTensors = reorderedInputs;
            log('🔄 Reordered inputs based on tensor names');
          }
        }
      } catch (e) {
        log('⚠️ Could not reorder inputs: $e');
      }

      // Run inference
      try {
        Map<int, Object> outputs = {0: outputTensors[0]};
        _interpreter!.runForMultipleInputs(inputTensors, outputs);

        List<double> logits = (outputs[0] as List<List<double>>)[0];

        // Apply softmax to convert logits to probabilities
        List<double> probabilities = _softmax(logits);

        log('📊 Raw logits: $logits');
        log('📊 Probabilities: $probabilities');

        String result = probabilities[0] > probabilities[1] ? 'Neutral' : 'Hostile';
        double confidence = probabilities[result == 'Neutral' ? 0 : 1];
        log('🧠 Prediction debug: Neutral prob=${probabilities[0]}, Hostile prob=${probabilities[1]}, Result=$result');


        return {
          'result': result,
          'confidence': confidence,
          'probabilities': probabilities,
          'logits': logits
        };
      } catch (e) {
        log('❌ Inference execution error: $e');
        // Fallback to neutral with warning
        return {
          'result': 'Neutral',
          'confidence': 1.0,
          'probabilities': [1.0, 0.0],
          'logits': [0.0, 0.0],
          'error': e.toString()
        };
      }
    } catch (e) {
      log('❌ Inference preparation error: $e');
      throw Exception('Inference failed: $e');
    }
  }

  // Convert logits to probabilities using softmax
  static List<double> _softmax(List<double> logits) {
    // Find the maximum logit (for numerical stability)
    double maxLogit = logits.reduce(math.max);

    // Subtract max for numerical stability and calculate exp
    List<double> expLogits = logits.map((logit) => math.exp(logit - maxLogit)).toList();

    // Calculate sum of exponentiated values
    double sumExp = expLogits.reduce((a, b) => a + b);

    // Normalize to get probabilities
    return expLogits.map((expLogit) => expLogit / sumExp).toList();
  }

  // Helper to pad or truncate to length
  static List<int> _padOrTruncate(List<int> input, int length) {
    if (input.length > length) {
      return input.sublist(0, length);
    } else if (input.length < length) {
      return input + List.filled(length - input.length, 0);
    } else {
      return input;
    }
  }

  // Method to resize tensor inputs if needed (for dynamic shape handling)
  static Future<void> _resizeTensorInputs(String text) async {
    final tokenizer = MobileBertTokenizer();
    final tokens = await tokenizer.tokenize(text);

    // Get actual sequence length
    int actualLength = tokens['input_ids']!.length;

    // Resize interpreter inputs if needed (only works if model supports dynamic shapes)
    try {
      _interpreter!.resizeInputTensor(0, [1, actualLength]);
      _interpreter!.resizeInputTensor(1, [1, actualLength]);
      _interpreter!.resizeInputTensor(2, [1, actualLength]);
      _interpreter!.allocateTensors();
    } catch (e) {
      // If resizing fails, we'll use padding/truncation instead
      log('⚠️ Tensor resizing not supported: $e');
    }
  }

  static void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
    _interpreter = null;
    _inputShapes = null;
    _outputShapes = null;
  }
}