import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuizGame extends StatefulWidget {
  final int energy;
  final int coins;
  final Function(int, int) onGameComplete;

  QuizGame({
    required this.energy,
    required this.coins,
    required this.onGameComplete,
  });

  @override
  _QuizGameState createState() => _QuizGameState();
}

class _QuizGameState extends State<QuizGame> {
  int currentQuestionIndex = 0;
  int correctAnswers = 0;
  late int currentEnergy;
  late int currentCoins;

  // Placeholder questions themed around Truyền thuyết Hồ Gươm and water puppetry
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
    currentEnergy = widget.energy - 10; // Deduct 10% energy to play
    currentCoins = widget.coins;
  }

  void _answerQuestion(String selectedAnswer) {
    HapticFeedback.selectionClick();
    if (selectedAnswer == questions[currentQuestionIndex]['correctAnswer']) {
      setState(() {
        correctAnswers++;
        currentCoins += 50; // Reward 50 coins for correct answer
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Correct! +50 coins'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wrong! Try again next time.'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }

    setState(() {
      currentQuestionIndex++;
    });

    if (currentQuestionIndex >= questions.length) {
      // Quiz complete, show results and return to main screen
      widget.onGameComplete(currentEnergy, currentCoins);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.blue.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Quiz Complete!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You got $correctAnswers out of ${questions.length} correct!\nEarned ${correctAnswers * 50} coins.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to GameSelectionPage
                Navigator.pop(context); // Return to HomePage
              },
              child: Text(
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
              // Top Bar with Back Button and Progress
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        widget.onGameComplete(currentEnergy, currentCoins);
                        Navigator.pop(context);
                      },
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
                      'Question ${currentQuestionIndex + 1}/${questions.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 40), // Balance layout
                  ],
                ),
              ),
              // Question Area
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade400,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ...questions[currentQuestionIndex]['options'].map<Widget>((option) {
                        return Container(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: ElevatedButton(
                            onPressed: () => _answerQuestion(option),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade400,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
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
        ),
      ),
    );
  }
}