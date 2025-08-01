import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late AnimationController _bounceController;
  late AnimationController _heartController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _heartAnimation;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _heartController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
    ));

    _heartAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _heartController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _heartController.dispose();
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
  }

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
              Color(0xFF4A7C59),
              Color(0xFF2F5233),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
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
            // Character Background
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF87CEEB),
                    Color(0xFF4682B4),
                  ],
                ),
              ),
            ),
            
            // Character
            Center(
              child: GestureDetector(
                onTap: _onCharacterTap,
                child: AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _bounceAnimation.value),
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.brown.shade300,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Character Face
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Hat
                                  Container(
                                    width: 80,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.brown.shade200,
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  // Eyes
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: 20),
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 15),
                                  // Mouth
                                  Container(
                                    width: 30,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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