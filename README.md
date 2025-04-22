# chat_app

1. UI is cloned from :https://github.com/swkhan-dev/ChatApp_FlutterFirebase
   Thanks to him for sharing the code.

2. For Hate Speech detection, `mobile bert` is used.

   - we first fined tuned the model on Roman Urdu using the dataset[https://www.kaggle.com/datasets/drkhurramshahzad/hate-speech-roman-urdu] from kaggle.
   - Quantized the model to int8 to reduce the size
   - Encrypt the model to pretect it/making difficult to reverse engineer before sending it to client machine
   - Actual model = 95.2 MB after fine tunning --- After quantization = 25.6 MB --- and after encryption = 34.1 MB --- Aditional 922KB ~ 1 MB for tokenizer

3. tokenization consideration
   considering implementing a proper WordPiece tokenizer to match the AutoTokenizer used in your fine-tuning code for the google/mobilebert-uncased model. The threee options for this are: (1) writing a native plugin in C++ using SentencePiece for WordPiece tokenization, or (2) implementing a WordPiece tokenizer in Dart. (3) using the Python AutoTokenizer (from Hugging Face’s transformers library) via embedded Python approach - pros and cons of each technique are bellow
   - we went with dart
