
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' show AudioEncoder, AudioRecorder, RecordConfig;
import 'package:permission_handler/permission_handler.dart';

class SpeechEmotionService {
  final AudioRecorder _recorder = AudioRecorder(); // Use AudioRecorder for record >= 5.0.0
  bool _isInitialized = false;
  String _status = 'Press to record';
  String _transcribedText = '';
  String _dominantEmotion = '';
  List<Map<String, dynamic>> _emotionResults = [];
  
  // Backend URL - Update this to your Flask server URL
  static const String _backendUrl = 'http://172.28.240.138'; // Change to your server IP
  // For Android emulator: 'http://10.0.2.2:5000'
  // For iOS simulator: 'http://localhost:5000'
  // For real device: 'http://YOUR_COMPUTER_IP:5000'

  bool _isListening = false;

  bool get isListening => _isListening;
  String get status => _status;
  String get transcribedText => _transcribedText;
  String get dominantEmotion => _dominantEmotion;
  List<Map<String, dynamic>> get emotionResults => _emotionResults;

  Future<void> initialize() async {
    try {
      // Check if audio recording is supported
      bool hasPermission = await _recorder.hasPermission();
      if (hasPermission) {
        _isInitialized = true;
        // Test backend connection
        await _testBackendConnection();
        _status = 'Press to record';
      } else {
        _status = 'Audio recording permission not granted';
      }
    } catch (e) {
      _status = 'Error initializing audio: $e';
      print('Initialization error: $e');
    }
  }

  Future<void> _testBackendConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Backend connection successful');
        print('Models loaded: ${data['models_loaded']}');
      } else {
        print('Backend connection failed: ${response.statusCode}');
        _status = 'Backend server not available';
      }
    } catch (e) {
      print('Backend connection error: $e');
      _status = 'Cannot connect to backend server';
    }
  }

  Future<void> startListening(void Function(String, String, List<Map<String, dynamic>>) onResult) async {
    if (!_isInitialized) {
      _status = 'Audio not initialized';
      onResult(_status, _transcribedText, _emotionResults);
      return;
    }

    if (await Permission.microphone.request().isGranted) {
      _transcribedText = '';
      _dominantEmotion = '';
      _emotionResults = [];
      _status = 'Listening...';
      _isListening = true;
      onResult(_status, _transcribedText, _emotionResults);

      try {
        // Create a temporary file to store the recording
        final directory = await getTemporaryDirectory();
        final audioPath = '${directory.path}/temp_audio.wav';

        // Start recording
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
          ),
          path: audioPath,
        );

        // Record for 5 seconds
        await Future.delayed(Duration(seconds: 5));

        // Stop recording and get the file path
        final recordedPath = await _recorder.stop();
        _isListening = false;

        _status = 'Processing emotions...';
        onResult(_status, _transcribedText, _emotionResults);

        // Send the recorded audio to the backend
        if (recordedPath != null) {
          final audioFile = File(recordedPath);
          if (await audioFile.exists()) {
            await _analyzeAudioFile(audioFile, onResult);
            await audioFile.delete(); // Clean up the temporary file
          } else {
            _status = 'Error: Audio file not found';
            onResult(_status, _transcribedText, _emotionResults);
          }
        } else {
          _status = 'Error: No audio recorded';
          onResult(_status, _transcribedText, _emotionResults);
        }
      } catch (e) {
        _isListening = false;
        _status = 'Error recording: $e';
        print('Recording error: $e');
        onResult(_status, _transcribedText, _emotionResults);
      }
    } else {
      _isListening = false;
      _status = 'Microphone permission denied';
      onResult(_status, _transcribedText, _emotionResults);
    }
  }

  Future<void> _analyzeAudioFile(File audioFile, void Function(String, String, List<Map<String, dynamic>>) onResult) async {
    _status = 'Processing audio...';
    _transcribedText = '';
    _emotionResults = [];
    _dominantEmotion = '';
    onResult(_status, _transcribedText, _emotionResults);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_backendUrl/transcribe_and_analyze'));
      request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
      
      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          _transcribedText = data['transcribed_text'] ?? '';
          
          if (data['emotions'] != null) {
            final emotions = List<Map<String, dynamic>>.from(data['emotions']);
            
            _emotionResults = emotions.map((emotion) => {
              'label': emotion['label'],
              'score': emotion['score'] / 100.0, // Convert to 0-1 range
              'percentage': emotion['score'], // Keep percentage for display
            }).toList();
          }
          
          if (data['dominant_emotion'] != null) {
            final dominant = data['dominant_emotion'];
            _dominantEmotion = '${dominant['label']} (${dominant['score'].toStringAsFixed(2)}%)';
          }
          
          _status = data['message'] ?? 'Analysis complete';
        } else {
          _status = 'Analysis failed: ${data['error']}';
        }
      } else {
        final errorData = jsonDecode(response.body);
        _status = 'Backend error: ${errorData['error']}';
      }
    } catch (e) {
      _status = 'Error processing audio: $e';
      print('Audio analysis error: $e');
    }
    
    onResult(_status, _transcribedText, _emotionResults);
  }

  Future<void> transcribeAudioFile(File audioFile, void Function(String, String, List<Map<String, dynamic>>) onResult) async {
    _status = 'Transcribing audio...';
    _transcribedText = '';
    _emotionResults = [];
    _dominantEmotion = '';
    onResult(_status, _transcribedText, _emotionResults);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_backendUrl/transcribe'));
      request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
      
      var streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          _transcribedText = data['transcribed_text'] ?? '';
          _status = data['message'] ?? 'Transcription complete';
        } else {
          _status = 'Transcription failed: ${data['error']}';
        }
      } else {
        final errorData = jsonDecode(response.body);
        _status = 'Backend error: ${errorData['error']}';
      }
    } catch (e) {
      _status = 'Error transcribing audio: $e';
      print('Transcription error: $e');
    }
    
    onResult(_status, _transcribedText, _emotionResults);
  }

  Future<void> transcribeAudioBytes(Uint8List audioBytes, void Function(String, String, List<Map<String, dynamic>>) onResult) async {
    _status = 'Transcribing audio...';
    _transcribedText = '';
    _emotionResults = [];
    _dominantEmotion = '';
    onResult(_status, _transcribedText, _emotionResults);

    try {
      String audioBase64 = base64Encode(audioBytes);
      
      final response = await http.post(
        Uri.parse('$_backendUrl/transcribe_base64'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'audio_data': audioBase64}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          _transcribedText = data['transcribed_text'] ?? '';
          _status = data['message'] ?? 'Transcription complete';
        } else {
          _status = 'Transcription failed: ${data['error']}';
        }
      } else {
        final errorData = jsonDecode(response.body);
        _status = 'Backend error: ${errorData['error']}';
      }
    } catch (e) {
      _status = 'Error transcribing audio: $e';
      print('Audio transcription error: $e');
    }
    
    onResult(_status, _transcribedText, _emotionResults);
  }

  Future<void> analyzeTextDirectly(String text, void Function(String, String, List<Map<String, dynamic>>) onResult) async {
    if (text.isEmpty) {
      _status = 'No text provided';
      onResult(_status, '', []);
      return;
    }

    _status = 'Analyzing emotions...';
    _transcribedText = text;
    _emotionResults = [];
    _dominantEmotion = '';
    onResult(_status, _transcribedText, _emotionResults);

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/analyze_emotions'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final emotions = List<Map<String, dynamic>>.from(data['emotions']);
          
          _emotionResults = emotions.map((emotion) => {
            'label': emotion['label'],
            'score': emotion['score'] / 100.0, // Convert to 0-1 range
            'percentage': emotion['score'], // Keep percentage for display
          }).toList();
          
          if (data['dominant_emotion'] != null) {
            final dominant = data['dominant_emotion'];
            _dominantEmotion = '${dominant['label']} (${dominant['score'].toStringAsFixed(2)}%)';
          }
          
          _status = 'Analysis complete';
        } else {
          _status = 'Emotion analysis failed: ${data['error']}';
        }
      } else {
        final errorData = jsonDecode(response.body);
        _status = 'Backend error: ${errorData['error']}';
      }
    } catch (e) {
      _status = 'Error analyzing emotions: $e';
      print('Emotion analysis error: $e');
    }
    
    onResult(_status, _transcribedText, _emotionResults);
  }

  void stop() {
    if (_isListening) {
      _recorder.stop();
      _isListening = false;
    }
    _status = 'Press to record';
  }

  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Backend status: ${data['status']}');
        print('Models loaded: ${data['models_loaded']}');
        return true;
      }
      return false;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getBackendHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Health check failed: $e');
      return null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
