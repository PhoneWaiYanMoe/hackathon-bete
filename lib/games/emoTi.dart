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
  Interpreter? _interpreter;
  late List<CameraDescription> _cameras;
  bool _isCameraInitialized = false;
  bool _isModelLoaded = false;
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

    _initializeCameraAndModel();
  }

  Future<void> _initializeCameraAndModel() async {
    try {
      // First check camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        _showError('Camera permission denied. Please enable camera access in settings.');
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showError('No cameras found on this device.');
        return;
      }

      // Find front camera
      CameraDescription? frontCamera;
      try {
        frontCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
      } catch (e) {
        frontCamera = _cameras.first;
      }

      // Initialize camera
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController.initialize();
      
      setState(() {
        _isCameraInitialized = true;
      });

      // Load the model with improved error handling
      await _loadModel();

      // Only start emotion detection if both camera and model are ready
      if (_isCameraInitialized && _isModelLoaded) {
        _startEmotionDetection();
      }

    } catch (e) {
      _showError('Error initializing camera: $e');
    }
  }

  Future<void> _loadModel() async {
    try {
      print('Starting model loading...');
      
      // Check if model file exists with more detailed logging
      ByteData? modelData;
      try {
        modelData = await rootBundle.load('assets/model/model_file_30epochs.tflite');
        print('Model file loaded successfully. Size: ${modelData.lengthInBytes} bytes');
      } catch (e) {
        print('Model file loading failed: $e');
        _showError('Model file not found. Please ensure "assets/model/model_file_30epochs.tflite" exists in your assets folder and is properly declared in pubspec.yaml');
        return;
      }

      // Create interpreter with minimal options first
      try {
        print('Creating interpreter...');
        
        // Try without any options first
        _interpreter = await Interpreter.fromAsset('assets/model/model_file_30epochs.tflite');
        print('Interpreter created successfully without options');
        
      } catch (e) {
        print('Failed to create interpreter without options: $e');
        
        // Try with basic options
        try {
          final interpreterOptions = InterpreterOptions();
          interpreterOptions.threads = 1;
          
          _interpreter = await Interpreter.fromAsset(
            'assets/model/model_file_30epochs.tflite',
            options: interpreterOptions,
          );
          print('Interpreter created successfully with basic options');
          
        } catch (e2) {
          print('Failed to create interpreter with options: $e2');
          _showError('Error creating model interpreter: $e2\n\nThis might be due to:\n1. Model incompatibility with current tflite_flutter version\n2. Corrupted model file\n3. Unsupported model operations');
          return;
        }
      }

      // Verify model structure
      try {
        final inputTensors = _interpreter!.getInputTensors();
        final outputTensors = _interpreter!.getOutputTensors();
        
        print('Number of input tensors: ${inputTensors.length}');
        print('Number of output tensors: ${outputTensors.length}');
        
        if (inputTensors.isNotEmpty) {
          final inputShape = inputTensors[0].shape;
          final inputType = inputTensors[0].type;
          print('Input tensor shape: $inputShape');
          print('Input tensor type: $inputType');
          
          // More flexible shape checking
          if (inputShape.length >= 3) {
            print('Model appears to have valid input dimensions');
          } else {
            print('Warning: Unexpected input shape: $inputShape');
          }
        }
        
        if (outputTensors.isNotEmpty) {
          final outputShape = outputTensors[0].shape;
          final outputType = outputTensors[0].type;
          print('Output tensor shape: $outputShape');
          print('Output tensor type: $outputType');
        }
        
      } catch (e) {
        print('Warning: Could not verify model structure: $e');
        // Continue anyway, as some models might still work
      }

      setState(() {
        _isModelLoaded = true;
      });

      print('Model loaded and verified successfully!');

    } catch (e) {
      print('Unexpected error in _loadModel: $e');
      _showError('Unexpected error loading model: $e');
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
      // Return to previous screen after showing error
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  void _startEmotionDetection() {
    if (!_isCameraInitialized || !_isModelLoaded) {
      print('Cannot start emotion detection: Camera initialized: $_isCameraInitialized, Model loaded: $_isModelLoaded');
      return;
    }

    _emotionTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isProcessing && 
          _isCameraInitialized && 
          _isModelLoaded &&
          _currentChainIndex < _emotionChains.length && 
          _interpreter != null &&
          mounted) {
        
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
          } else if (_detectedEmotion.isNotEmpty) {
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
    if (!_cameraController.value.isInitialized || _interpreter == null || !mounted) {
      return;
    }

    try {
      final image = await _cameraController.takePicture();
      final bytes = await image.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        if (mounted) {
          setState(() {
            _detectedEmotion = 'No face';
          });
        }
        return;
      }

      // Get model input requirements dynamically
      final inputTensors = _interpreter!.getInputTensors();
      if (inputTensors.isEmpty) {
        print('No input tensors found');
        return;
      }
      
      final inputShape = inputTensors[0].shape;
      print('Processing with input shape: $inputShape');
      
      // Extract dimensions (handle different model formats)
      int inputHeight = 48;  // default
      int inputWidth = 48;   // default
      int channels = 1;      // default to grayscale
      
      if (inputShape.length == 4) {
        // Format: [batch, height, width, channels] or [batch, channels, height, width]
        if (inputShape[1] == inputShape[2]) {
          // Likely [batch, height, width, channels]
          inputHeight = inputShape[1];
          inputWidth = inputShape[2];
          channels = inputShape[3];
        } else if (inputShape[2] == inputShape[3]) {
          // Likely [batch, channels, height, width]
          channels = inputShape[1];
          inputHeight = inputShape[2];
          inputWidth = inputShape[3];
        }
      }
      
      print('Using dimensions: ${inputWidth}x${inputHeight}x$channels');

      // Crop to center square for better face detection
      final width = decodedImage.width;
      final height = decodedImage.height;
      final cropSize = min(width, height);
      final x = (width - cropSize) ~/ 2;
      final y = (height - cropSize) ~/ 2;
      
      final subImage = img.copyCrop(
        decodedImage,
        x: x,
        y: y,
        width: cropSize,
        height: cropSize,
      );

      // Convert to grayscale and resize
      final grayImage = img.grayscale(subImage);
      final resized = img.copyResize(grayImage, width: inputWidth, height: inputHeight);

      // Prepare input tensor with proper shape
      final inputSize = inputHeight * inputWidth * channels;
      final input = Float32List(inputSize);
      
      var pixelIndex = 0;
      for (int y = 0; y < inputHeight; y++) {
        for (int x = 0; x < inputWidth; x++) {
          final pixel = resized.getPixel(x, y);
          // Normalize pixel value to [0, 1]
          final normalizedValue = (pixel.r / 255.0);
          input[pixelIndex] = normalizedValue;
          pixelIndex++;
        }
      }

      // Prepare output tensor
      final outputTensors = _interpreter!.getOutputTensors();
      final outputShape = outputTensors[0].shape;
      final outputSize = outputShape.reduce((a, b) => a * b);
      final output = Float32List(outputSize);
      
      // Run inference with proper tensor shapes
      try {
        if (inputShape.length == 4) {
          _interpreter!.run(
            [input.reshape([1, inputHeight, inputWidth, channels])], 
            {0: output.reshape([1, outputSize ~/ 1])}
          );
        } else {
          _interpreter!.run([input], {0: output});
        }
        
        // Get prediction (assuming output is emotion probabilities)
        double maxValue = output[0];
        int maxIndex = 0;
        
        final numClasses = min(output.length, _emotions.length);
        for (int i = 1; i < numClasses; i++) {
          if (output[i] > maxValue) {
            maxValue = output[i];
            maxIndex = i;
          }
        }

        // Update UI with detected emotion
        if (mounted && maxIndex < _emotions.length) {
          setState(() {
            _detectedEmotion = _emotions[maxIndex];
          });
          print('Detected emotion: ${_emotions[maxIndex]} (confidence: ${maxValue.toStringAsFixed(3)})');
        }

      } catch (e) {
        print('Inference error: $e');
        if (mounted) {
          setState(() {
            _detectedEmotion = 'Inference Error';
          });
        }
      }

    } catch (e) {
      print('Error processing camera frame: $e');
      if (mounted) {
        setState(() {
          _detectedEmotion = 'Processing Error';
        });
      }
    }
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
    _interpreter?.close();
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
                  // Top Bar
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
                              'Status: ${_isModelLoaded ? "Ready" : "Loading..."}',
                              style: TextStyle(
                                color: _isModelLoaded ? Colors.green : Colors.orange,
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

                  // Camera Feed
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

                  // Detection Status
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

                  // Emotion Chain Display
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

              // Chú Tễu Character
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