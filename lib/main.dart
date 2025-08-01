import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'dart:async';
import 'dart:math';
import 'games/quiz.dart';
import 'games/pickTwo.dart';

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
  int energy = 85;
  int coins = 1250;
  bool isPremium = false;
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;
  
  // Fun Facts System
  Timer? _funFactTimer;
  String? _currentFunFact;
  bool _showFunFact = false;
  late AnimationController _funFactController;
  late Animation<double> _funFactAnimation;
  late Animation<Offset> _funFactSlideAnimation;

  // List of fun facts about Vietnamese water puppetry and culture
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

    // Initialize fun fact animations
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

    // Start the fun fact timer
    _startFunFactTimer();
  }

  void _startFunFactTimer() {
    // Random interval between 15-45 seconds
    int randomSeconds = 15 + Random().nextInt(30);
    
    _funFactTimer = Timer(Duration(seconds: randomSeconds), () {
      _showRandomFunFact();
      _startFunFactTimer(); // Schedule next fun fact
    });
  }

  void _showRandomFunFact() {
    if (!mounted) return;
    
    // Pick a random fun fact
    String randomFact = _funFacts[Random().nextInt(_funFacts.length)];
    
    setState(() {
      _currentFunFact = randomFact;
      _showFunFact = true;
    });

    // Show the fun fact with animation
    _funFactController.forward();

    // Hide the fun fact after 4 seconds
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

  @override
  void dispose() {
    _heartController.dispose();
    _funFactController.dispose();
    _funFactTimer?.cancel();
    super.dispose();
  }

  void _onCharacterTap() {
    HapticFeedback.lightImpact();
    _heartController.forward().then((_) {
      _heartController.reverse();
    });

    setState(() {
      if (energy > 5) {
        energy -= 5;
      }
    });

    // Chance to trigger immediate fun fact on character tap
    if (Random().nextInt(4) == 0 && !_showFunFact) { // 25% chance
      _showRandomFunFact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/img/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top HUD
                  _buildTopHUD(),
                  
                  // Character Area
                  Expanded(
                    flex: 3,
                    child: _buildCharacterArea(),
                  ),
                  
                  // Main Action Button
                  _buildPlayGamesButton(),
                  
                  // Daily Reward
                  _buildDailyReward(),
                  
                  SizedBox(height: 20),
                ],
              ),
              
              // Fun Fact Overlay
              if (_showFunFact && _currentFunFact != null)
                _buildFunFactOverlay(),
            ],
          ),
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
            // Speech bubble
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
          // Energy Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade400,
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
                Icon(Icons.water_drop, color: Colors.white, size: 16),
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
          
          // Coins
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade400,
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
          
          // Premium & Settings
          Row(
            children: [
              GestureDetector(
                onTap: () => _onButtonTap('Premium', context),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade400,
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
            // 3D Character Model
            GestureDetector(
              onTap: _onCharacterTap,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: ModelViewer(
                  backgroundColor: Colors.transparent,
                  src: 'assets/glb/c_neutral.glb',
                  alt: 'Water Puppet Character',
                  ar: false,
                  autoRotate: true,
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
            
            // Heart Animation
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
            
            // Tap instruction (optional)
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
                    'Tap to interact!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayGamesButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ElevatedButton(
        onPressed: () {
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
                  });
                },
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade500,
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
            Icon(Icons.games, size: 24),
            SizedBox(width: 10),
            Text(
              'PLAY GAMES',
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
              'Daily Reward Available!',
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

    // Main rounded rectangle
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 10),
      Radius.circular(radius),
    ));

    // Triangle for speech tail
    path.moveTo(size.width / 2 - 10, size.height - 10);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width / 2 + 10, size.height - 10);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
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
              // Top Bar with Back Button
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
                    SizedBox(width: 40), // Balance layout
                  ],
                ),
              ),
              // Game List
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameButton(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
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