import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'speech_emotion_service.dart';
import 'games/quiz.dart';
import 'games/pickTwo.dart';
import 'games/emoTi.dart';
import 'games/storyWeaver.dart';

void main() {
  runApp(WaterPuppetApp());
}

class WaterPuppetApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hồ Gươm Quest',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

void _onButtonTap(String action, BuildContext context) {
  HapticFeedback.selectionClick();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$action feature coming soon!'),
      duration: Duration(seconds: 1),
      backgroundColor: Colors.green.shade600,
    ),
  );
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int energy = 100;
  int coins = 1250;
  bool isPremium = false;
  bool isSleeping = false;
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;
  late AnimationController _sleepController;
  late Animation<double> _sleepAnimation;
  Timer? _energyRechargeTimer;

  // Fun Facts System
  Timer? _funFactTimer;
  String? _currentFunFact;
  bool _showFunFact = false;
  late AnimationController _funFactController;
  late Animation<double> _funFactAnimation;
  late Animation<Offset> _funFactSlideAnimation;
  final List<String> _funFacts = [
    "🎭 Water puppetry originated over 1000 years ago in the Red River Delta!",
    "💧 Traditional shows feature live folk music with drums, gongs, and wooden bells.",
    "🐉 The Golden Dragon is the most popular character in water puppet shows.",
    "🏛️ Hoan Kiem Lake is home to the legendary Golden Turtle God.",
    "🎨 Puppeteers stand waist-deep in water behind a bamboo screen.",
    "🌾 Water puppetry began as entertainment for rice farmers during floods.",
    "🎪 Each puppet show tells stories of Vietnamese folklore and daily life.",
    "🏮 The art form was once exclusive to northern Vietnamese villages.",
    "🎵 Traditional water puppet music uses ancient Vietnamese instruments.",
    "🌟 UNESCO recognized water puppetry as Intangible Cultural Heritage.",
  ];

  // Storage System
  List<Map<String, dynamic>> inventory = [];
  String? equippedSkin;
  File? _storageFile;

  // Speech and Emotion System
  final SpeechEmotionService _speechService = SpeechEmotionService();
  String _currentGlb = 'assets/glb/c_neutral.glb';
  String _transcribedText = '';
  String _dominantEmotion = '';
  List<Map<String, dynamic>> _emotionResults = [];
  String _status = 'Press to record';

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _heartAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _heartController,
      curve: Curves.elasticOut,
    ));

    _sleepController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _sleepAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sleepController,
      curve: Curves.easeInOut,
    ));

    _funFactController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _funFactAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _funFactController,
      curve: Curves.elasticOut,
    ));
    _funFactSlideAnimation = Tween<Offset>(
      begin: Offset(0, -1),
      end: Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _funFactController,
      curve: Curves.easeOutBack,
    ));

    // Initialize storage
    _initStorage();

    // Initialize speech service
    _requestMicPermission();

    // Start fun fact timer if not sleeping
    if (energy >= 10) {
      _startFunFactTimer();
    }

    // Check for sleep mode
    if (energy < 10) {
      _enterSleepMode();
    }
  }

  Future<void> _requestMicPermission() async {
    if (await Permission.microphone.request().isGranted) {
      await _speechService.initialize();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Microphone permission denied'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<void> _initStorage() async {
    final directory = await getApplicationDocumentsDirectory();
    _storageFile = File('${directory.path}/storage.json');
    if (await _storageFile!.exists()) {
      final content = await _storageFile!.readAsString();
      final data = jsonDecode(content);
      setState(() {
        inventory = List<Map<String, dynamic>>.from(data['inventory'] ?? []);
        equippedSkin = data['equippedSkin'];
      });
    } else {
      await _saveStorage();
    }
  }

  Future<void> _saveStorage() async {
    if (_storageFile == null) return;
    final data = {
      'inventory': inventory,
      'equippedSkin': equippedSkin,
    };
    await _storageFile!.writeAsString(jsonEncode(data));
  }

  void _startFunFactTimer() {
    if (isSleeping) return;
    int randomSeconds = 15 + Random().nextInt(30);
    _funFactTimer = Timer(Duration(seconds: randomSeconds), () {
      _showRandomFunFact();
      _startFunFactTimer();
    });
  }

  void _showRandomFunFact() {
    if (!mounted || isSleeping) return;
    String randomFact = _funFacts[Random().nextInt(_funFacts.length)];
    setState(() {
      _currentFunFact = randomFact;
      _showFunFact = true;
    });
    _funFactController.forward();
    Timer(Duration(seconds: 4), () {
      if (mounted) {
        _funFactController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showFunFact = false;
              _currentFunFact = null;
            });
          }
        });
      }
    });
  }

  void _enterSleepMode() {
    setState(() {
      isSleeping = true;
    });
    _sleepController.forward();
    _funFactTimer?.cancel();
    _energyRechargeTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (mounted && isSleeping) {
        setState(() {
          if (energy < 100) {
            energy = (energy + 1).clamp(0, 100);
          }
          if (energy >= 90) {
            _wakeUp();
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _wakeUp() {
    setState(() {
      isSleeping = false;
    });
    _sleepController.reverse();
    _energyRechargeTimer?.cancel();
    _startFunFactTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Your puppet is refreshed and ready to play! 🌟'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  void _forceSleep() {
    if (!isSleeping) {
      _enterSleepMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your puppet is now sleeping to recharge... 😴'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.indigo.shade600,
        ),
      );
    }
  }

  void _onCharacterTap() {
    if (isSleeping) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shh... your puppet is sleeping! 😴'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.indigo.shade600,
        ),
      );
      return;
    }
    HapticFeedback.lightImpact();
    _heartController.forward().then((_) {
      _heartController.reverse();
    });
    setState(() {
      if (energy > 5) {
        energy -= 5;
        if (energy < 10) {
          Timer(Duration(milliseconds: 500), () {
            _enterSleepMode();
          });
        }
      }
    });
    if (Random().nextInt(4) == 0 && !_showFunFact && !isSleeping) {
      _showRandomFunFact();
    }
  }

  void _openShop() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopPage(
          coins: coins,
          onPurchase: (int newCoins, Map<String, dynamic> item) {
            setState(() {
              coins = newCoins;
              inventory.add(item);
              _saveStorage();
            });
          },
        ),
      ),
    );
  }

  void _openStorage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoragePage(
          inventory: inventory,
          equippedSkin: equippedSkin,
          onUseWater: (String waterType) {
            setState(() {
              int energyBoost = 0;
              if (waterType == 'Spring Water') {
                energyBoost = 20;
              } else if (waterType == 'Rain Water') {
                energyBoost = 50;
              } else if (waterType == 'River Water') {
                energyBoost = 80;
              }
              energy = (energy + energyBoost).clamp(0, 100);
              inventory.removeWhere((item) => item['name'] == waterType && item['type'] == 'water');
              if (isSleeping && energy >= 10) {
                _wakeUp();
              }
              _saveStorage();
            });
          },
          onEquipSkin: (String skinName) {
            setState(() {
              equippedSkin = skinName;
              _saveStorage();
            });
          },
        ),
      ),
    );
  }

  void _updateEmotionResults(String status, String text, List<Map<String, dynamic>> emotions) {
    setState(() {
      _status = status;
      _transcribedText = text;
      _emotionResults = emotions;
      _dominantEmotion = emotions.isNotEmpty
          ? '${emotions[0]['label']} (${(emotions[0]['score'] * 100).toStringAsFixed(2)}%)'
          : '';
      _updateGlbModel(emotions.isNotEmpty ? emotions[0]['label'] : 'neutral');
    });
  }

  void _updateGlbModel(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'angry':
      case 'anger':
        _currentGlb = 'assets/glb/c_angry.glb';
        break;
      case 'sad':
      case 'negative':
        _currentGlb = 'assets/glb/c_cry.glb';
        break;
      case 'disgust':
        _currentGlb = 'assets/glb/c_disgust.glb';
        break;
      case 'happy':
      case 'positive':
        _currentGlb = 'assets/glb/c_smile.glb';
        break;
      case 'neutral':
      default:
        _currentGlb = 'assets/glb/c_neutral.glb';
        break;
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    _sleepController.dispose();
    _funFactController.dispose();
    _funFactTimer?.cancel();
    _energyRechargeTimer?.cancel();
    _speechService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sleepAnimation,
      builder: (context, child) {
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/img/background.png'),
                fit: BoxFit.cover,
                colorFilter: isSleeping
                    ? ColorFilter.mode(
                        Colors.indigo.shade900.withOpacity(0.7),
                        BlendMode.overlay,
                      )
                    : null,
              ),
            ),
            child: Container(
              decoration: isSleeping
                  ? BoxDecoration(
                      color: Colors.black.withOpacity(_sleepAnimation.value * 0.6),
                    )
                  : null,
              child: SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _buildTopHUD(),
                        Expanded(
                          flex: 3,
                          child: _buildCharacterArea(),
                        ),
                        _buildMainActionButton(),
                        if (!isSleeping) _buildDailyReward(),
                        SizedBox(height: 20),
                      ],
                    ),
                    if (_showFunFact && _currentFunFact != null && !isSleeping)
                      _buildFunFactOverlay(),
                    if (isSleeping) _buildSleepOverlay(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSleepOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _sleepAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.8 + (_sleepAnimation.value * 0.2),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade800.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.bedtime,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            Text(
              'Sleeping...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Recharging energy',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            if (energy >= 5)
              ElevatedButton(
                onPressed: _wakeUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade400,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Wake Up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunFactOverlay() {
    return Positioned(
      top: 120,
      left: 30,
      right: 30,
      child: ScaleTransition(
        scale: _funFactAnimation,
        child: Stack(
          children: [
            Container(
              margin: EdgeInsets.only(bottom: 20),
              child: CustomPaint(
                painter: SpeechBubblePainter(),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lightbulb,
                                  color: Colors.orange.shade600,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Did you know?',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Spacer(),
                          GestureDetector(
                            onTap: () {
                              _funFactController.reverse().then((_) {
                                setState(() {
                                  _showFunFact = false;
                                  _currentFunFact = null;
                                });
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                color: Colors.grey.shade400,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        _currentFunFact!,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHUD() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: energy < 10
                  ? (isSleeping ? Colors.indigo.shade600 : Colors.red.shade400)
                  : Colors.blue.shade400,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  energy < 10
                      ? (isSleeping ? Icons.bedtime : Icons.battery_alert)
                      : Icons.water_drop,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  '$energy%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSleeping ? Colors.grey.shade600 : Colors.amber.shade400,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
              Icon(Icons.monetization_on, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  '${coins.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _onButtonTap('Daily Reward', context),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSleeping ? Colors.grey.shade700 : Colors.amber.shade400,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.card_giftcard, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: isSleeping ? null : _openShop,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSleeping ? Colors.grey.shade700 : Colors.green.shade400,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.store, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: isSleeping ? null : _openStorage,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSleeping ? Colors.grey.shade700 : Colors.blue.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.inventory, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () => _onButtonTap('Premium', context),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSleeping ? Colors.grey.shade700 : Colors.orange.shade400,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.star, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: isSleeping ? null : _forceSleep,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSleeping ? Colors.grey.shade700 : Colors.indigo.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.bedtime, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () => _onButtonTap('Settings', context),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.settings, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterArea() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            GestureDetector(
              onTap: _onCharacterTap,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: ModelViewer(
                  backgroundColor: Colors.transparent,
                  src: equippedSkin != null && !isSleeping ? 'assets/glb/$equippedSkin.glb' : _currentGlb,
                  alt: 'Water Puppet Character',
                  ar: false,
                  autoRotate: !isSleeping,
                  autoRotateDelay: 3000,
                  rotationPerSecond: '30deg',
                  cameraControls: true,
                  disableZoom: true,
                  touchAction: TouchAction.none,
                  interactionPrompt: InteractionPrompt.none,
                  cameraOrbit: '0deg 75deg 4.5m',
                  minCameraOrbit: 'auto 50deg auto',
                  maxCameraOrbit: 'auto 100deg auto',
                  fieldOfView: '30deg',
                  loading: Loading.eager,
                ),
              ),
            ),
            if (!isSleeping)
              Positioned(
                top: 20,
                right: 20,
                child: AnimatedBuilder(
                  animation: _heartAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _heartAnimation.value,
                      child: Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 30,
                      ),
                    );
                  },
                ),
              ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    isSleeping ? 'Sleeping...' : 'Tap to interact!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            if (equippedSkin != null)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Skin: $equippedSkin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (!isSleeping)
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _speechService.isListening
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              _speechService.startListening(_updateEmotionResults);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade400,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        _speechService.isListening ? 'Recording...' : 'Record Speech',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Status: $_status',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Emotion: ${_dominantEmotion.isEmpty ? "None" : _dominantEmotion}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActionButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ElevatedButton(
        onPressed: () {
          if (isSleeping) {
            return;
          } else if (energy < 10) {
            _forceSleep();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameSelectionPage(
                  energy: energy,
                  coins: coins,
                  onGameComplete: (newEnergy, newCoins) {
                    setState(() {
                      energy = newEnergy;
                      coins = newCoins;
                      if (energy < 10) {
                        Timer(Duration(milliseconds: 500), () {
                          _enterSleepMode();
                        });
                      }
                    });
                  },
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSleeping
              ? Colors.grey.shade600
              : (energy < 10 ? Colors.indigo.shade500 : Colors.red.shade500),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: isSleeping ? 2 : 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSleeping
                  ? Icons.bedtime
                  : (energy < 10 ? Icons.bedtime : Icons.games),
              size: 24,
            ),
            SizedBox(width: 10),
            Text(
              isSleeping
                  ? 'SLEEPING...'
                  : (energy < 10 ? 'GO TO SLEEP' : 'PLAY GAMES'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyReward() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: ElevatedButton(
        onPressed: () => _onButtonTap('Daily Reward', context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber.shade400,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard, size: 20),
            SizedBox(width: 8),
            Text(
              'Daily Reward',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpeechBubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    final radius = 20.0;
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 10),
      Radius.circular(radius),
    ));
    path.moveTo(size.width / 2 - 10, size.height - 10);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width / 2 + 10, size.height - 10);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ShopPage extends StatelessWidget {
  final int coins;
  final Function(int, Map<String, dynamic>) onPurchase;

  ShopPage({required this.coins, required this.onPurchase});

  final List<Map<String, dynamic>> shopItems = [
    {'name': 'Spring Water', 'type': 'water', 'price': 100, 'energy': 20},
    {'name': 'Rain Water', 'type': 'water', 'price': 250, 'energy': 50},
    {'name': 'River Water', 'type': 'water', 'price': 400, 'energy': 80},
    {'name': 'Bamboo Skin', 'type': 'skin', 'price': 500},
    {'name': 'Lotus Skin', 'type': 'skin', 'price': 750},
    {'name': 'Dragon Skin', 'type': 'skin', 'price': 1000},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade400,
        title: Text('Shop', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7FB069), Color(0xFF2F5233)],
          ),
        ),
        child: ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: shopItems.length,
          itemBuilder: (context, index) {
            final item = shopItems[index];
            return Card(
              color: Colors.white.withOpacity(0.9),
              margin: EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: Icon(
                  item['type'] == 'water' ? Icons.water_drop : Icons.color_lens,
                  color: Colors.blue.shade600,
                  size: 30,
                ),
                title: Text(
                  item['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  item['type'] == 'water'
                      ? 'Restores ${item['energy']}% energy'
                      : 'Decorative skin (no visual change)',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: ElevatedButton(
                  onPressed: coins >= item['price']
                      ? () {
                          HapticFeedback.selectionClick();
                          onPurchase(coins - (item['price'] as num).toInt(), item);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Purchased ${item['name']}!'),
                              duration: Duration(seconds: 1),
                              backgroundColor: Colors.green.shade600,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('${item['price']} Coins'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class StoragePage extends StatelessWidget {
  final List<Map<String, dynamic>> inventory;
  final String? equippedSkin;
  final Function(String) onUseWater;
  final Function(String) onEquipSkin;

  StoragePage({
    required this.inventory,
    required this.equippedSkin,
    required this.onUseWater,
    required this.onEquipSkin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade400,
        title: Text('Storage', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7FB069), Color(0xFF2F5233)],
          ),
        ),
        child: inventory.isEmpty
            ? Center(
                child: Text(
                  'Storage is empty!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: inventory.length,
                itemBuilder: (context, index) {
                  final item = inventory[index];
                  return Card(
                    color: Colors.white.withOpacity(0.9),
                    margin: EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ListTile(
                      leading: Icon(
                        item['type'] == 'water' ? Icons.water_drop : Icons.color_lens,
                        color: Colors.blue.shade600,
                        size: 30,
                      ),
                      title: Text(
                        item['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        item['type'] == 'water'
                            ? 'Restores ${item['energy']}% energy'
                            : item['name'] == equippedSkin
                                ? 'Equipped'
                                : 'Decorative skin',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: item['type'] == 'water'
                          ? ElevatedButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                onUseWater(item['name']);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Used ${item['name']}!'),
                                    duration: Duration(seconds: 1),
                                    backgroundColor: Colors.green.shade600,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade400,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text('Use'),
                            )
                          : ElevatedButton(
                              onPressed: item['name'] == equippedSkin
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      onEquipSkin(item['name']);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Equipped ${item['name']}!'),
                                          duration: Duration(seconds: 1),
                                          backgroundColor: Colors.green.shade600,
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade400,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(item['name'] == equippedSkin ? 'Equipped' : 'Equip'),
                            ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class GameSelectionPage extends StatelessWidget {
  final int energy;
  final int coins;
  final Function(int, int) onGameComplete;

  GameSelectionPage({
    required this.energy,
    required this.coins,
    required this.onGameComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7FB069),
              Color(0xFF2F5233),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      ),
                    ),
                    Text(
                      'Select a Game',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildGameButton(
                      context,
                      title: 'Quiz',
                      icon: Icons.quiz,
                      color: Colors.blue.shade400,
                      onTap: () {
                        if (energy >= 10) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizGame(
                                energy: energy,
                                coins: coins,
                                onGameComplete: onGameComplete,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Not enough energy! Need 10%.'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.red.shade600,
                            ),
                          );
                        }
                      },
                    ),
                    _buildGameButton(
                      context,
                      title: 'Pick Two',
                      icon: Icons.grid_view,
                      color: Colors.purple.shade400,
                      onTap: () {
                        if (energy >= 10) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PickTwoGame(),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Not enough energy! Need 10%.'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.red.shade600,
                            ),
                          );
                        }
                      },
                    ),
                    _buildGameButton(
                      context,
                      title: 'Story Weaver',
                      icon: Icons.book,
                      color: Colors.green.shade400,
                      onTap: () {
                        if (energy >= 10) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoryWeaverGame(
                                energy: energy,
                                coins: coins,
                                onGameComplete: onGameComplete,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Not enough energy! Need 10%.'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.red.shade600,
                            ),
                          );
                        }
                      },
                    ),
                    _buildGameButton(
                      context,
                      title: 'EmoTi',
                      icon: Icons.face,
                      color: Colors.orange.shade400,
                      onTap: () {
                        if (energy >= 10) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EmoTiGame(
                                energy: energy,
                                coins: coins,
                                onGameComplete: onGameComplete,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Not enough energy! Need 10%.'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.red.shade600,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameButton(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
