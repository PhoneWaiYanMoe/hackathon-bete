import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';

class EmoTiGame extends StatefulWidget {
  final int energy;
  final int coins;
  final Function(int, int) onGameComplete;

  const EmoTiGame({
    required this.energy,
    required this.coins,
    required this.onGameComplete,
    super.key,
  });

  @override
  _EmoTiGameState createState() => _EmoTiGameState();
}

enum ChuTeuState { natural, correct, wrong, result }

class _EmoTiGameState extends State<EmoTiGame> with TickerProviderStateMixin {
  late CameraController _cameraController;
  late Interpreter _interpreter;
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
    _currentEnergy = widget.energy - 10; // Deduct 10 energy to play
    _currentCoins = widget.coins;

    // Initialize Chú Tễu animation
    _chuTeuController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _chuTeuAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _chuTeuController, curve: Curves.easeInOut),
    );

    // Initialize emotion chains
    _emotionChains = List.generate(5, (_) {
      final length = 3 + Random().nextInt(3); // 3 to 5 emotions
      final chain = <String>[];
      final availableEmotions = List<String>.from(_emotions);
      for (int i = 0; i < length; i++) {
        if (availableEmotions.isEmpty) availableEmotions.addAll(_emotions);
        chain.add((availableEmotions..shuffle(Random())).removeAt(0));
      }
      return chain;
    });

    // Initialize stage
    _usedStages = [];
    _currentStage = (_stageImages..shuffle(Random())).first;
    _usedStages.add(_currentStage);

    // Initialize camera and model
    _initializeCameraAndModel();
    // Start emotion detection
    _startEmotionDetection();
  }

  Future<void> _initializeCameraAndModel() async {
    try {
      // Request camera permission
      if (await Permission.camera.request().isGranted) {
        _cameras = await availableCameras();
        _cameraController = CameraController(
          _cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front),
          ResolutionPreset.medium,
        );
        await _cameraController.initialize();
        setState(() {
          _isCameraInitialized = true;
        });

        // Load TFLite model
        _interpreter = await Interpreter.fromAsset('assets/model/model_file_30epochs.tflite');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission denied')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing camera or model: $e')),
      );
      Navigator.pop(context);
    }
  }

  void _startEmotionDetection() {
    _emotionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isProcessing && _isCameraInitialized && _currentChainIndex < _emotionChains.length) {
        _isProcessing = true;
        await _processCameraFrame();
        _isProcessing = false;

        // Check if emotion matches
        final targetEmotion = _emotionChains[_currentChainIndex][_currentEmotionIndex];
        if (_detectedEmotion == targetEmotion) {
          setState(() {
            _correctEmotions++;
            _currentCoins += 50;
            _chuTeuState = ChuTeuState.correct;
            _chuTeuController.repeat(reverse: true);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Emotion matched! +50 coins'),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.green.shade600,
            ),
          );
          _nextEmotion();
        } else {
          setState(() {
            _chuTeuState = ChuTeuState.wrong;
            _chuTeuController.repeat(reverse: true);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Wrong emotion!'),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.red.shade600,
            ),
          );
          _nextEmotion();
        }
      }
    });
  }

  Future<void> _processCameraFrame() async {
    if (!_cameraController.value.isInitialized) return;

    try {
      final image = await _cameraController.takePicture();
      final bytes = await image.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        setState(() {
          _detectedEmotion = '';
        });
        return;
      }

      // Crop central 50% of the image to approximate face detection
      final width = decodedImage.width;
      final height = decodedImage.height;
      final cropSize = (min(width, height) * 0.5).toInt();
      final x = (width - cropSize) ~/ 2;
      final y = (height - cropSize) ~/ 2;
      final subImage = img.copyCrop(
        decodedImage,
        x: x,
        y: y,
        width: cropSize,
        height: cropSize,
      );

      // Convert to grayscale
      final grayImage = img.grayscale(subImage);

      // Resize to 48x48
      final resized = img.copyResize(grayImage, width: 48, height: 48);

      // Normalize pixel values
      final normalized = Float32List(48 * 48);
      for (int y = 0; y < 48; y++) {
        for (int x = 0; x < 48; x++) {
          final pixel = resized.getPixel(x, y);
          // Since image is grayscale, red channel equals luminance
          // final grayValue = img.getRed(pixel) / 255.0;
          // normalized[y * 48 + x] = grayValue;
        }
      }
      final input = normalized.reshape([1, 48, 48, 1]);

      // Run inference
      final output = Float32List(7).reshape([1, 7]);
      _interpreter.run(input, output);
      final label = output[0].indexOf(output[0].reduce(max));
      setState(() {
        _detectedEmotion = _emotions[label];
      });
    } catch (e) {
      setState(() {
        _detectedEmotion = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing frame: $e')),
      );
    }
  }

  void _nextEmotion() {
    setState(() {
      _currentEmotionIndex++;
      if (_currentEmotionIndex >= _emotionChains[_currentChainIndex].length) {
        _currentChainIndex++;
        _currentEmotionIndex = 0;

        // Select new stage for next chain
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

      // Revert Chú Tễu after 1 second
      Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _chuTeuState = ChuTeuState.natural;
          _chuTeuController.reset();
        });
      });

      // End game if all chains are complete
      if (_currentChainIndex >= _emotionChains.length) {
        _emotionTimer?.cancel();
        widget.onGameComplete(_currentEnergy, _currentCoins);
        setState(() {
          _chuTeuState = ChuTeuState.result;
        });
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
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Return to GameSelectionPage
                  Navigator.pop(context); // Return to HomePage
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
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _interpreter.close();
    _emotionTimer?.cancel();
    _chuTeuController.dispose();
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
        chuTeuImage = 'assets/img/ChuTeuNatural.png';
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
                  // Top Bar with Back Button and Progress
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
                        Text(
                          'Chain ${_currentChainIndex + 1}/5',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 40), // Balance layout
                      ],
                    ),
                  ),
                  // Camera Feed and Emotion Display
                  if (_isCameraInitialized)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      height: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CameraPreview(_cameraController),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    _detectedEmotion.isEmpty ? 'No face detected' : 'Detected: $_detectedEmotion',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Emotion Chain Display
                  if (_currentChainIndex < _emotionChains.length)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
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
                    ),
                ],
              ),
              // Chú Tễu Image with Animation
              Positioned(
                bottom: 20,
                right: 20,
                child: AnimatedBuilder(
                  animation: _chuTeuAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        _chuTeuState == ChuTeuState.wrong ? _chuTeuAnimation.value : 0.0,
                        _chuTeuState == ChuTeuState.correct ? _chuTeuAnimation.value : 0.0,
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