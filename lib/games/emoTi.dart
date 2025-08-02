import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class EmoTiGame extends StatefulWidget {
  final int energy;
  final int coins;
  final Function(int, int) onGameComplete;
  final VoidCallback? onSleep;

  const EmoTiGame({
    required this.energy,
    required this.coins,
    required this.onGameComplete,
    this.onSleep,
    super.key,
  });

  @override
  _EmoTiGameState createState() => _EmoTiGameState();
}

enum ChuTeuState { natural, correct, wrong, result }

class _EmoTiGameState extends State<EmoTiGame> with TickerProviderStateMixin {
  late CameraController _cameraController;
  late List<CameraDescription> _cameras;
  bool _isCameraInitialized = false;
  late List<List<String>> _emotionChains;
  int _currentChainIndex = 0;
  int _currentEmotionIndex = 0;
  int _correctEmotions = 0;
  late int _currentEnergy;
  late int _currentCoins;
  ChuTeuState _chuTeuState = ChuTeuState.natural;
  String _currentStage = '';
  List<String> _usedStages = [];
  late AnimationController _chuTeuController;
  late Animation<double> _chuTeuAnimation;
  String _detectedEmotion = '';
  Timer? _emotionTimer;
  bool _isProcessing = false;

  final List<String> _stageImages = [
    'assets/img/Stage1(quiz).png',
    'assets/img/Stage2(quiz).png',
    'assets/img/Stage3(quiz).png',
    'assets/img/Stage4(quiz).png',
    'assets/img/Stage5(quiz).png',
    'assets/img/Stage6(quiz).png',
    'assets/img/Stage7(quiz).png',
    'assets/img/Stage8(quiz).png',
  ];

  final List<String> _emotions = [
    'Angry', 'Disgust', 'Fear', 'Happy', 'Neutral', 'Sad', 'Surprise'
  ];

  @override
  void initState() {
    super.initState();
    _currentEnergy = widget.energy - 10;
    _currentCoins = widget.coins;

    _chuTeuController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _chuTeuAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _chuTeuController, curve: Curves.easeInOut),
    );

    _emotionChains = List.generate(5, (_) {
      final length = 3 + Random().nextInt(3);
      final chain = <String>[];
      final availableEmotions = List<String>.from(_emotions);
      for (int i = 0; i < length; i++) {
        if (availableEmotions.isEmpty) availableEmotions.addAll(_emotions);
        chain.add((availableEmotions..shuffle(Random())).removeAt(0));
      }
      return chain;
    });

    _usedStages = [];
    _currentStage = (_stageImages..shuffle(Random())).first;
    _usedStages.add(_currentStage);

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        _showError('Camera permission denied. Please enable camera access in settings.');
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('No cameras found on this device.');
        return;
      }

      CameraDescription? frontCamera;
      try {
        frontCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
      } catch (e) {
        frontCamera = _cameras.first;
      }

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController.initialize();

      setState(() {
        _isCameraInitialized = true;
      });

      _startEmotionDetection();
    } catch (e) {
      _showError('Error initializing camera: $e');
    }
  }

  void _showError(String message) {
    print('EmoTi Game Error: $message');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red.shade600,
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _startEmotionDetection() {
    if (!_isCameraInitialized) {
      print('Cannot start emotion detection: Camera not initialized');
      return;
    }

    _emotionTimer = Timer.periodic(const Duration(seconds: 5), (timer) async { // Increased to 5 seconds
      if (!_isProcessing && _isCameraInitialized && _currentChainIndex < _emotionChains.length && mounted) {
        _isProcessing = true;
        await _processCameraFrame();
        _isProcessing = false;

        if (mounted && _currentChainIndex < _emotionChains.length) {
          final targetEmotion = _emotionChains[_currentChainIndex][_currentEmotionIndex];
          if (_detectedEmotion == targetEmotion) {
            setState(() {
              _correctEmotions++;
              _currentCoins += 50;
              _chuTeuState = ChuTeuState.correct;
              _chuTeuController.repeat(reverse: true);
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Emotion matched! +50 coins'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: Colors.green.shade600,
                ),
              );
            }
            _nextEmotion();
          } else if (_detectedEmotion.isNotEmpty && _detectedEmotion != 'No face') { // Added check for 'No face'
            setState(() {
              _chuTeuState = ChuTeuState.wrong;
              _chuTeuController.repeat(reverse: true);
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Need: $targetEmotion, Got: $_detectedEmotion'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: Colors.red.shade600,
                ),
              );
            }

            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) _nextEmotion();
            });
          }
        }
      }
    });
  }

  Future<void> _processCameraFrame() async {
    if (!_cameraController.value.isInitialized || !mounted) return;

    try {
      final image = await _cameraController.takePicture();
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      print('Captured image, base64 length: ${base64Image.length}'); // Debug

      final response = await http.post(
        Uri.parse('http://172.28.240.138:5001/detect_face_emotion_base64'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_data': base64Image}),
      );

      print('Backend response status: ${response.statusCode}'); // Debug
      print('Backend response body: ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['primary_face'] != null) {
          final emotion = data['primary_face']['emotion']?.toString() ?? 'No face';
          final confidence = data['primary_face']['confidence']?.toDouble() ?? 0.0;

          print('Raw emotion from backend: $emotion, Confidence: $confidence'); // Debug raw data

          if (confidence >= 50.0) { // Add confidence threshold
            if (mounted) {
              setState(() {
                _detectedEmotion = _normalizeEmotionLabel(emotion);
              });
              print('Detected emotion: $_detectedEmotion (confidence: ${confidence.toStringAsFixed(3)})'); // Debug
            }
          } else {
            if (mounted) {
              setState(() {
                _detectedEmotion = 'No face'; // Fallback if confidence is too low
              });
              print('Low confidence detection: $confidence%'); // Debug
            }
          }
        } else {
          setState(() {
            _detectedEmotion = 'No face';
          });
          print('No valid emotion or face detected in response: ${data['message']}'); // Debug message
        }
      } else {
        setState(() {
          _detectedEmotion = 'Server Error';
        });
        print('Server error: ${response.statusCode} - ${response.body}'); // Debug
      }
    } catch (e) {
      print('Error processing camera frame: $e'); // Debug
      if (mounted) {
        setState(() {
          _detectedEmotion = 'Processing Error';
        });
      }
    }
  }

  String _normalizeEmotionLabel(String emotion) {
    final normalized = emotion.toLowerCase();
    if (normalized.contains('angry')) return 'Angry';
    if (normalized.contains('disgust')) return 'Disgust';
    if (normalized.contains('fear')) return 'Fear';
    if (normalized.contains('happy')) return 'Happy';
    if (normalized.contains('neutral')) return 'Neutral';
    if (normalized.contains('sad')) return 'Sad';
    if (normalized.contains('surprise')) return 'Surprise';
    return 'Neutral'; // Default fallback
  }

  void _nextEmotion() {
    if (!mounted) return;

    setState(() {
      _currentEmotionIndex++;
      if (_currentEmotionIndex >= _emotionChains[_currentChainIndex].length) {
        _currentChainIndex++;
        _currentEmotionIndex = 0;

        List<String> availableStages = _stageImages.where((stage) => !_usedStages.contains(stage)).toList();
        if (availableStages.isNotEmpty) {
          _currentStage = (availableStages..shuffle(Random())).first;
          _usedStages.add(_currentStage);
        } else {
          _usedStages = [];
          _currentStage = (_stageImages..shuffle(Random())).first;
          _usedStages.add(_currentStage);
        }
      }

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _chuTeuState = ChuTeuState.natural;
            _chuTeuController.reset();
          });
        }
      });

      if (_currentChainIndex >= _emotionChains.length) {
        _emotionTimer?.cancel();
        widget.onGameComplete(_currentEnergy, _currentCoins);
        setState(() {
          _chuTeuState = ChuTeuState.result;
        });

        _showGameCompleteDialog();
      }
    });
  }

  void _showGameCompleteDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blue.shade400,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/img/ChuTeuResult.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 10),
            const Text(
              'Game Complete!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'You matched $_correctEmotions emotions!\nEarned ${_correctEmotions * 50} coins.',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Back to Home',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emotionTimer?.cancel();
    _chuTeuController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String chuTeuImage;
    switch (_chuTeuState) {
      case ChuTeuState.correct:
        chuTeuImage = 'assets/img/ChuTeuCorrect.png';
        break;
      case ChuTeuState.wrong:
        chuTeuImage = 'assets/img/ChuTeuWrong.png';
        break;
      case ChuTeuState.result:
        chuTeuImage = 'assets/img/ChuTeuResult.png';
        break;
      case ChuTeuState.natural:
      default:
        chuTeuImage = 'assets/img/ChuTeuNeutural.png';
        break;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_currentStage),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            widget.onGameComplete(_currentEnergy, _currentCoins);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade600,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              'Chain ${_currentChainIndex + 1}/5',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Status: ${_isCameraInitialized ? "Ready" : "Loading..."}',
                              style: TextStyle(
                                color: _isCameraInitialized ? Colors.green : Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: widget.onSleep != null
                              ? () {
                                  widget.onGameComplete(_currentEnergy, _currentCoins);
                                  widget.onSleep!();
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.onSleep != null ? Colors.indigo.shade600 : Colors.grey.shade600,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.bedtime, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isCameraInitialized)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      height: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CameraPreview(_cameraController),
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      _detectedEmotion.isEmpty ? 'Detecting...' : 'Detected: $_detectedEmotion',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_currentChainIndex < _emotionChains.length)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Show these emotions:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _emotionChains[_currentChainIndex].asMap().entries.map((entry) {
                              final index = entry.key;
                              final emotion = entry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: index == _currentEmotionIndex
                                        ? Colors.amber.shade400
                                        : index < _currentEmotionIndex
                                            ? Colors.green.shade600
                                            : Colors.blue.shade400,
                                    borderRadius: BorderRadius.circular(10),
                                    border: index == _currentEmotionIndex
                                        ? Border.all(color: Colors.white, width: 2)
                                        : null,
                                  ),
                                  child: Text(
                                    emotion,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: AnimatedBuilder(
                  animation: _chuTeuAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        _chuTeuState == ChuTeuState.wrong ? _chuTeuAnimation.value : 0.0,
                        _chuTeuState == ChuTeuState.correct ? -_chuTeuAnimation.value : 0.0,
                      ),
                      child: Image.asset(
                        chuTeuImage,
                        width: 100,
                        height: 100,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}