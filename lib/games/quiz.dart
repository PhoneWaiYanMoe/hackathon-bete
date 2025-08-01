import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class QuizGame extends StatefulWidget {
  final int energy;
  final int coins;
  final Function(int, int) onGameComplete;

  const QuizGame({
    required this.energy,
    required this.coins,
    required this.onGameComplete,
    super.key,
  });

  @override
  _QuizGameState createState() => _QuizGameState();
}

enum ChuTeuState { natural, correct, wrong, result }

class _QuizGameState extends State<QuizGame> with TickerProviderStateMixin {
  int currentQuestionIndex = 0;
  int correctAnswers = 0;
  late int currentEnergy;
  late int currentCoins;
  ChuTeuState chuTeuState = ChuTeuState.natural;
  Color questionCardColor = Colors.blue.withOpacity(0.3); // 0.0 = fully transparent, 1.0 = fully opaque
  late AnimationController _chuTeuController;
  late Animation<double> _chuTeuAnimation;
  String currentStage = '';
  List<String> usedStages = [];
  final List<String> stageImages = [
    'assets/img/Stage1(quiz).png',
    'assets/img/Stage2(quiz).png',
    'assets/img/Stage3(quiz).png',
    'assets/img/Stage4(quiz).png',
    'assets/img/Stage5(quiz).png',
    'assets/img/Stage6(quiz).png',
    'assets/img/Stage7(quiz).png',
    'assets/img/Stage8(quiz).png',
  ];

  final List<Map<String, dynamic>> questions = [
    {
      'question': 'What is the name of the lake in Truyền thuyết Hồ Gươm?',
      'options': ['Hoan Kiem Lake', 'West Lake', 'Truc Bach Lake', 'Ba Be Lake'],
      'correctAnswer': 'Hoan Kiem Lake',
    },
    {
      'question': 'Who is the hero in the Legend of the Returned Sword?',
      'options': ['Le Loi', 'Nguyen Trai', 'Tran Hung Dao', 'Ly Thai To'],
      'correctAnswer': 'Le Loi',
    },
    {
      'question': 'What creature gives Le Loi the magical sword?',
      'options': ['Dragon', 'Tortoise', 'Phoenix', 'Lion'],
      'correctAnswer': 'Tortoise',
    },
    {
      'question': 'What is the name of the jester in water puppetry?',
      'options': ['Chú Tễu', 'Anh Hùng', 'Cô Tiên', 'Ông Rùa'],
      'correctAnswer': 'Chú Tễu',
    },
    {
      'question': 'What dynasty is associated with water puppetry’s origin?',
      'options': ['Ly Dynasty', 'Tran Dynasty', 'Nguyen Dynasty', 'Le Dynasty'],
      'correctAnswer': 'Ly Dynasty',
    },
    {
      'question': 'What material are water puppets typically made from?',
      'options': ['Bamboo', 'Fig Wood', 'Clay', 'Metal'],
      'correctAnswer': 'Fig Wood',
    },
    {
      'question': 'What does the dragon symbolize in water puppetry?',
      'options': ['Wisdom', 'Power', 'Peace', 'Love'],
      'correctAnswer': 'Power',
    },
    {
      'question': 'What is the water puppet stage called?',
      'options': ['Thuy Dinh', 'Nha Rong', 'Den Tho', 'Chua Mot Cot'],
      'correctAnswer': 'Thuy Dinh',
    },
    {
      'question': 'What effect enhances dragon scenes in water puppetry?',
      'options': ['Fireworks', 'Bubbles', 'Lights', 'Fog'],
      'correctAnswer': 'Fireworks',
    },
    {
      'question': 'What does Le Loi return to the tortoise?',
      'options': ['Shield', 'Crown', 'Sword', 'Boat'],
      'correctAnswer': 'Sword',
    },
  ];

  @override
  void initState() {
    super.initState();
    currentEnergy = widget.energy - 10; // Deduct 10 energy to play
    currentCoins = widget.coins;

    // Initialize stage for the first question
    usedStages = [];
    currentStage = (stageImages..shuffle(Random())).first;
    usedStages.add(currentStage);

    _chuTeuController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _chuTeuAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _chuTeuController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _chuTeuController.dispose();
    super.dispose();
  }

  void _answerQuestion(String selectedAnswer) {
    HapticFeedback.selectionClick();
    if (selectedAnswer == questions[currentQuestionIndex]['correctAnswer']) {
      setState(() {
        correctAnswers++;
        currentCoins += 50; // Reward 50 coins for correct answer
        chuTeuState = ChuTeuState.correct;
        // questionCardColor = Colors.green.shade600;
        _chuTeuController.repeat(reverse: true); // Bounce up-down
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Correct! +50 coins'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } else {
      setState(() {
        chuTeuState = ChuTeuState.wrong;
        // questionCardColor = Colors.red.shade600;
        _chuTeuController.repeat(reverse: true); // Shake side-to-side
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Wrong! Try again next time.'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }

    // Revert Chú Tễu and question card after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        chuTeuState = ChuTeuState.natural;
        questionCardColor = Colors.blue.withOpacity(0.3);
        _chuTeuController.reset();
      });
    });

    setState(() {
      currentQuestionIndex++;
      // Select new stage for next question if not at the end
      if (currentQuestionIndex < questions.length) {
        List<String> availableStages = stageImages.where((stage) => !usedStages.contains(stage)).toList();
        if (availableStages.isNotEmpty) {
          currentStage = (availableStages..shuffle(Random())).first;
          usedStages.add(currentStage);
        } else {
          // Reset usedStages if all stages are used (for quizzes with more than 8 questions)
          usedStages = [currentStage];
          currentStage = (stageImages..shuffle(Random())).first;
          usedStages.add(currentStage);
        }
      }
    });

    if (currentQuestionIndex >= questions.length) {
      // Quiz complete, show results and return to main screen
      widget.onGameComplete(currentEnergy, currentCoins);
      setState(() {
        chuTeuState = ChuTeuState.result;
        usedStages = []; // Reset for next quiz session
      });
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.blue.withOpacity(0.3),
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
                'Quiz Complete!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'You got $correctAnswers out of ${questions.length} correct!\nEarned ${correctAnswers * 50} coins.',
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
  }

  @override
  Widget build(BuildContext context) {
    String chuTeuImage;
    switch (chuTeuState) {
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
            image: AssetImage(currentStage),
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
                            widget.onGameComplete(currentEnergy, currentCoins);
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
                          'Question ${currentQuestionIndex + 1}/${questions.length}',
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
                  // Question Area
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: questionCardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            questions[currentQuestionIndex]['question'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ...questions[currentQuestionIndex]['options'].map<Widget>((option) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ElevatedButton(
                                onPressed: () => _answerQuestion(option),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade400,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 4,
                                ),
                                child: Text(
                                  option,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
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
                        chuTeuState == ChuTeuState.wrong ? _chuTeuAnimation.value : 0.0,
                        chuTeuState == ChuTeuState.correct ? _chuTeuAnimation.value : 0.0,
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