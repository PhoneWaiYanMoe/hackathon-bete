import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
class SpeechEmotionService {
  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  String _status = 'Press to record';
  String _transcribedText = '';
  String _dominantEmotion = '';
  List<Map<String, dynamic>> _emotionResults = [];

  bool get isListening => _speech.isListening;
  String get status => _status;
  String get transcribedText => _transcribedText;
  String get dominantEmotion => _dominantEmotion;
  List<Map<String, dynamic>> get emotionResults => _emotionResults;

  Future<void> initialize() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) => _status = status,
        onError: (error) => _status = 'Error: $error',
      );
      _isInitialized = available;
      if (!available) {
        _status = 'Speech recognition not available';
      }
    } catch (e) {
      _status = 'Error initializing speech: $e';
    }
  }

  Future<void> startListening(void Function(String, String, List<Map<String, dynamic>>) onResult) async {
    if (!_isInitialized) {
      _status = 'Speech not initialized';
      onResult(_status, _transcribedText, _emotionResults);
      return;
    }

    _transcribedText = '';
    _dominantEmotion = '';
    _emotionResults = [];
    _status = 'Listening...';

    try {
      await _speech.listen(
        onResult: (result) {
          _transcribedText = result.recognizedWords;
          if (result.finalResult) {
            _status = 'Processing emotions...';
            _analyzeEmotions(_transcribedText, onResult);
          }
          onResult(_status, _transcribedText, _emotionResults);
        },
        listenFor: const Duration(seconds: 5),
        pauseFor: const Duration(seconds: 3),
        sampleRate: 16000,
      );
    } catch (e) {
      _status = 'Error recording: $e';
      onResult(_status, _transcribedText, _emotionResults);
    }
  }

  Future<void> _analyzeEmotions(String text, void Function(String, String, List<Map<String, dynamic>>) onResult) async {
    if (text.isEmpty) {
      _status = 'No speech detected';
      onResult(_status, _transcribedText, _emotionResults);
      return;
    }

    try {
      const apiUrl = 'https://api-inference.huggingface.co/models/j-hartmann/emotion-english-distilroberta-base';
      const apiKey = dotenv.env['HF_API_KEY'] ?? ''; // Replace with your API key

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'inputs': text}),
      );

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body)[0];
        final sortedEmotions = List<Map<String, dynamic>>.from(results)
          ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

        _emotionResults = sortedEmotions;
        _dominantEmotion = sortedEmotions.isNotEmpty
            ? '${sortedEmotions[0]['label']} (${(sortedEmotions[0]['score'] * 100).toStringAsFixed(2)}%)'
            : '';
        _status = 'Press to record';
      } else {
        _status = 'Emotion analysis failed: ${response.statusCode}';
      }
    } catch (e) {
      _status = 'Error analyzing emotions: $e';
    }
    onResult(_status, _transcribedText, _emotionResults);
  }

  void stop() {
    _speech.stop();
    _status = 'Press to record';
  }
}
