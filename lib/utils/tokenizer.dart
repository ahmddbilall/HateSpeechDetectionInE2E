import 'dart:convert';
import 'dart:developer';
import 'package:flutter/services.dart' show rootBundle;

class MobileBertTokenizer {
  late Map<String, int> vocab;
  late Map<String, String> specialTokens;
  static const int maxLength = 128;
  static const String unkToken = '[UNK]';
  static const String clsToken = '[CLS]';
  static const String sepToken = '[SEP]';
  static const String padToken = '[PAD]';
  bool _vocabLoaded = false;

  MobileBertTokenizer() {
    specialTokens = {
      'unk_token': unkToken,
      'cls_token': clsToken,
      'sep_token': sepToken,
      'pad_token': padToken,
    };
    vocab = {};
  }

  Future<void> loadVocab() async {
    if (_vocabLoaded) return;

    try {
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

      // Debug: print vocab size and some examples
      log('📚 Vocab size: ${vocab.length}');
      log('📚 First 10 vocab entries: ${vocab.entries.take(10).toList()}');

      // Ensure special tokens are correctly mapped
      if (!vocab.containsKey(clsToken)) {
        log('⚠️ [CLS] token not found in vocab, adding with ID 101');
        vocab[clsToken] = 101;
      }
      if (!vocab.containsKey(sepToken)) {
        log('⚠️ [SEP] token not found in vocab, adding with ID 102');
        vocab[sepToken] = 102;
      }
      if (!vocab.containsKey(padToken)) {
        log('⚠️ [PAD] token not found in vocab, adding with ID 0');
        vocab[padToken] = 0;
      }
      if (!vocab.containsKey(unkToken)) {
        log('⚠️ [UNK] token not found in vocab, adding with ID 100');
        vocab[unkToken] = 100;
      }

      _vocabLoaded = true;
    } catch (e) {
      log('❌ Error loading vocab: $e');
      throw Exception('Failed to load tokenizer vocabulary: $e');
    }
  }

  Future<Map<String, List<int>>> tokenize(String text) async {
    await loadVocab();

    // Handle empty or very short text specially
    if (text.trim().isEmpty) {
      log('⚠️ Empty text provided for tokenization');
      // Return minimal tokens (just [CLS] and [SEP])
      List<int> minimalIds = [vocab[clsToken]!, vocab[sepToken]!];
      List<int> minimalMask = [1, 1];
      List<int> minimalTypes = [0, 0];

      // Pad to maxLength
      minimalIds = _padTo(minimalIds, vocab[padToken]!);
      minimalMask = _padTo(minimalMask, 0);
      minimalTypes = _padTo(minimalTypes, 0);

      return {
        'input_ids': minimalIds,
        'attention_mask': minimalMask,
        'token_type_ids': minimalTypes,
      };
    }

    // Preprocess text: lowercase and clean
    String cleanedText = text.toLowerCase().trim();
    // Remove excess whitespace
    cleanedText = cleanedText.replaceAll(RegExp(r'\s+'), ' ');

    log('🧹 Cleaned text: "$cleanedText"');

    // Split into words
    List<String> words = cleanedText.split(' ');
    log('🔤 Word count: ${words.length}');

    // Tokenize with WordPiece
    List<String> tokens = [clsToken]; // Start with [CLS]

    for (String word in words) {
      if (word.isEmpty) continue;

      List<String> subTokens = _wordPieceTokenize(word);
      log('🔍 Word "$word" → tokens: $subTokens');

      // Check if adding these tokens would exceed maxLength - 1 (for [SEP])
      if (tokens.length + subTokens.length >= maxLength - 1) {
        // Truncate subTokens if needed
        int availableSpace = maxLength - 1 - tokens.length;
        if (availableSpace > 0) {
          subTokens = subTokens.sublist(0, availableSpace);
        } else {
          break; // No more space
        }
      }

      tokens.addAll(subTokens);
    }

    tokens.add(sepToken); // End with [SEP]
    log('🧩 Final tokens: $tokens');

    // Convert tokens to IDs
    List<int> inputIds = [];
    int unkId = vocab[unkToken]!;

    for (String token in tokens) {
      int id = vocab[token] ?? unkId;
      inputIds.add(id);
    }

    // Generate attention mask (1 for real tokens, 0 for padding)
    List<int> attentionMask = List.filled(inputIds.length, 1);

    // Generate token type IDs (0 for all in single-sequence case)
    List<int> tokenTypeIds = List.filled(inputIds.length, 0);

    // Pad to maxLength
    inputIds = _padTo(inputIds, vocab[padToken]!);
    attentionMask = _padTo(attentionMask, 0);
    tokenTypeIds = _padTo(tokenTypeIds, 0);

    log('🔢 First few input IDs: ${inputIds.take(10).toList()}');
    log('🔢 Last few input IDs: ${inputIds.sublist(inputIds.length - 10)}');

    return {
      'input_ids': inputIds,
      'attention_mask': attentionMask,
      'token_type_ids': tokenTypeIds,
    };
  }

  List<String> _wordPieceTokenize(String word) {
    if (word.isEmpty) return [];

    // Check if the whole word is in vocab
    if (vocab.containsKey(word)) {
      return [word];
    }

    List<String> subTokens = [];
    int start = 0;
    bool isFirst = true;

    while (start < word.length) {
      int end = word.length;
      String? curSubToken;

      // Try to find the longest subword from start to end
      while (start < end) {
        String subStr = word.substring(start, end);
        String subToken = isFirst ? subStr : '##$subStr';

        if (vocab.containsKey(subToken)) {
          curSubToken = subToken;
          break;
        }
        end -= 1;
      }

      // If no valid subtoken found, use [UNK]
      if (curSubToken == null) {
        subTokens.add(unkToken);
        break;
      }

      subTokens.add(curSubToken);
      start = end;
      isFirst = false;
    }

    // If tokenization failed completely, use [UNK]
    if (subTokens.isEmpty) {
      subTokens.add(unkToken);
    }

    return subTokens;
  }

  // Pad a list to specified length
  List<int> _padTo(List<int> list, int padValue) {
    if (list.length >= maxLength) {
      return list.sublist(0, maxLength);
    }
    return list + List.filled(maxLength - list.length, padValue);
  }
}