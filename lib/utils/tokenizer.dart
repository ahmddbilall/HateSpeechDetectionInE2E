import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class MobileBertTokenizer {
  late Map<String, int> vocab;
  late Map<String, String> specialTokens;
  static const int maxLength = 128;
  static const String unkToken = '[UNK]';
  static const String clsToken = '[CLS]';
  static const String sepToken = '[SEP]';
  static const String padToken = '[PAD]';

  MobileBertTokenizer() {
    specialTokens = {
      'unk_token': unkToken,
      'cls_token': clsToken,
      'sep_token': sepToken,
      'pad_token': padToken,
    };
  }

  Future<void> loadVocab() async {
    // Load vocab.txt from assets
    final vocabData = await rootBundle.loadString('assets/tokenizer/vocab.txt');

    // Parse vocab.txt lines into a map
    vocab = {};
    final lines = vocabData.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) {
        vocab[token] = i;
      }
    }

    // Ensure special tokens are correctly mapped
    if (!vocab.containsKey(clsToken)) vocab[clsToken] = 101;
    if (!vocab.containsKey(sepToken)) vocab[sepToken] = 102;
    if (!vocab.containsKey(padToken)) vocab[padToken] = 0;
    if (!vocab.containsKey(unkToken)) vocab[unkToken] = 100;
  }

  Future<Map<String, List<int>>> tokenize(String text) async {
    await loadVocab();

    // Preprocess text: lowercase and split into words
    String cleanedText = text.toLowerCase().trim();
    List<String> words = cleanedText.split(RegExp(r'\s+'));

    // Tokenize with WordPiece
    List<String> tokens = [clsToken]; // Start with [CLS]
    for (String word in words) {
      List<String> subTokens = _wordPieceTokenize(word);
      tokens.addAll(subTokens);
      if (tokens.length >= maxLength - 1) break; // Reserve space for [SEP]
    }
    tokens.add(sepToken); // End with [SEP]

    // Truncate to max_length
    if (tokens.length > maxLength) {
      tokens = tokens.sublist(0, maxLength - 1);
      tokens.add(sepToken);
    }

    // Convert tokens to input_ids
    List<int> inputIds = tokens.map((token) => vocab[token] ?? vocab[unkToken]!).toList();

    // Generate attention_mask and token_type_ids
    List<int> attentionMask = List.generate(inputIds.length, (_) => 1);
    List<int> tokenTypeIds = List.generate(inputIds.length, (_) => 0);

    // Create new lists with proper padding instead of adding to existing lists
    if (inputIds.length < maxLength) {
      int padCount = maxLength - inputIds.length;

      // Create new padded lists
      List<int> paddedInputIds = List<int>.from(inputIds)
        ..addAll(List.filled(padCount, vocab[padToken]!));

      List<int> paddedAttentionMask = List<int>.from(attentionMask)
        ..addAll(List.filled(padCount, 0));

      List<int> paddedTokenTypeIds = List<int>.from(tokenTypeIds)
        ..addAll(List.filled(padCount, 0));

      // Replace the original lists
      inputIds = paddedInputIds;
      attentionMask = paddedAttentionMask;
      tokenTypeIds = paddedTokenTypeIds;
    }

    return {
      'input_ids': inputIds,
      'attention_mask': attentionMask,
      'token_type_ids': tokenTypeIds,
    };
  }

  List<String> _wordPieceTokenize(String word) {
    List<String> subTokens = [];
    int start = 0;
    while (start < word.length) {
      int end = word.length;
      String? curSubToken;
      while (end > start) {
        String subToken = word.substring(start, end);
        if (start > 0) {
          subToken = '##$subToken';
        }
        if (vocab.containsKey(subToken)) {
          curSubToken = subToken;
          break;
        }
        end -= 1;
      }
      if (curSubToken == null) {
        subTokens.add(unkToken);
        break;
      }
      subTokens.add(curSubToken);
      start = end;
    }
    return subTokens;
  }
}