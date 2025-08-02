import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class SpeechEmotionService {
  final String _baseUrl = 'http://172.28.240.138:5000';
  final AudioRecorder _recorder = AudioRecorder();
  File? _audioFile;
  bool _isRecording = false;
  bool _isInitialized = false;
  final String _apiKey = 'AIzaSyABCmiB8TTFtfI80yLqxLHnqMWGKBpuXJU'; // Replace with your actual Gemini API key

  bool get isListening => _isRecording;

  Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _audioFile = File('${directory.path}/temp_audio.wav');
      final response = await http.get(Uri.parse('$_baseUrl/health'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['models_loaded']['whisper'] && data['models_loaded']['emotion']) {
          _isInitialized = true;
          print('SpeechEmotionService initialized successfully');
        } else {
          print('Models not loaded on backend');
        }
      } else {
        print('Backend health check failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error initializing SpeechEmotionService: $e');
      _isInitialized = false;
    }
  }

  Future<void> startListening(void Function(String, String, List<Map<String, dynamic>>, String?) callback) async {
    if (!_isInitialized) {
      callback('Error: Service not initialized', '', [], null);
      return;
    }

    try {
      if (await _recorder.hasPermission()) {
        _isRecording = true;
        await _recorder.start(const RecordConfig(), path: _audioFile!.path);
        print('Recording started');
        callback('Recording...', '', [], null);

        await Future.delayed(Duration(seconds: 5));
        await stop(callback);
      } else {
        callback('Microphone permission denied', '', [], null);
      }
    } catch (e) {
      print('Error starting recording: $e');
      _isRecording = false;
      callback('Error starting recording: $e', '', [], null);
    }
  }

  Future<void> stop([void Function(String, String, List<Map<String, dynamic>>, String?)? callback]) async {
    if (!_isRecording) {
      callback?.call('Not recording', '', [], null);
      return;
    }

    try {
      await _recorder.stop();
      _isRecording = false;
      print('Recording stopped, processing audio...');
      callback?.call('Processing...', '', [], null);

      final result = await _transcribeAndAnalyze();
      if (result['success']) {
        final transcribedText = result['transcribed_text'] ?? '';
        final emotions = (result['emotions'] as List<dynamic>?)?.map((e) => {
              'label': e['label'] as String,
              'score': (e['score'] / 100).toDouble(),
              'percentage': e['score'].toDouble(),
            }).toList() ?? [];
        final culturalResponse = await _generateCulturalResponse(transcribedText);
        callback?.call('Success', transcribedText, emotions, culturalResponse);
      } else {
        callback?.call('Error: ${result['error']}', '', [], null);
      }
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      callback?.call('Error stopping recording: $e', '', [], null);
    }
  }

  Future<Map<String, dynamic>> _transcribeAndAnalyze() async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/transcribe_and_analyze'));
      request.files.add(await http.MultipartFile.fromPath('audio', _audioFile!.path));
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (response.statusCode == 200 && data['success']) {
        print('Transcription and analysis successful: ${data['transcribed_text']}');
        return data;
      } else {
        print('Backend error: ${data['error']}');
        return {'success': false, 'error': data['error'] ?? 'Unknown error'};
      }
    } catch (e) {
      print('Error in transcribe_and_analyze: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<String?> _generateCulturalResponse(String transcribedText) async {
    if (transcribedText.isEmpty) {
      return null;
    }

    const String promptContext = '''
casually talking with user like a friend and make sure its short abt 1 to 2 sentences''';

    String fullPrompt = '''
$promptContext

User's input: $transcribedText

Response:
''';

    try {
      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': fullPrompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 64,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String text = data['candidates'][0]['content']['parts'][0]['text'];
        // Ensure the response is one sentence by truncating at the first period
        return text.split('.').first + '.';
      } else {
        print('Gemini API error: ${response.statusCode}');
        return _createMockCulturalResponse(transcribedText);
      }
    } catch (e) {
      print('Error calling Gemini API: $e');
      return _createMockCulturalResponse(transcribedText);
    }
  }

  String _createMockCulturalResponse(String input) {
    List<String> responses = [
      'By Hoan Kiem Lake, your words stirred the Golden Turtle to share wisdom.',
      'In the Red River’s mist, your voice inspired a dragon’s harmonious song.',
      'Amid bamboo groves, spirits blessed your words with ancient courage.',
    ];

    Random rand = Random();
    return responses[rand.nextInt(responses.length)];
  }

  Future<Map<String, dynamic>> transcribeAudioFile(File audioFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/transcribe'));
      request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody);
      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> analyzeTextDirectly(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analyze_emotions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}