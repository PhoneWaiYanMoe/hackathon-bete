// lib/games/pickTwo.dart
import 'package:flutter/material.dart';
import 'dart:math';

class PickTwoGame extends StatefulWidget {
  const PickTwoGame({Key? key}) : super(key: key);

  @override
  State<PickTwoGame> createState() => _PickTwoGameState();
}

class _PickTwoGameState extends State<PickTwoGame> {
  final List<String> _images = List.generate(8, (i) => 'm${i + 1}')..addAll(List.generate(8, (i) => 'm${i + 1}'))..shuffle();
  List<bool> _revealed = List.filled(16, false);
  List<int> _selectedIndices = [];
  bool _gameFinished = false;
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
  String _currentStage = '';

  void _onCardTap(int index) {
    if (_revealed[index] || _selectedIndices.length == 2) return;

    setState(() {
      _revealed[index] = true;
      _selectedIndices.add(index);

      if (_selectedIndices.length == 2) {
        Future.delayed(const Duration(milliseconds: 700), () {
          final a = _selectedIndices[0];
          final b = _selectedIndices[1];

          if (_images[a] != _images[b]) {
            setState(() {
              _revealed[a] = false;
              _revealed[b] = false;
            });
          } else {
            if (!_revealed.contains(false)) {
              setState(() {
                _gameFinished = true;
                usedStages = [];
                _currentStage = (stageImages..shuffle(Random())).first;
                usedStages.add(_currentStage);
              });
            }
          }
          _selectedIndices.clear();
        });
      }
    });
  }

  void _goToMain() {
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _currentStage = (stageImages..shuffle(Random())).first;
    usedStages.add(_currentStage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(_currentStage),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Top Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _goToMain,
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
                          'Level 1', // Static level for now; could be dynamic if needed
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Status: ${_gameFinished ? "Completed" : "In Progress"}',
                          style: TextStyle(
                            color: _gameFinished ? Colors.green : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    // Placeholder for additional button (e.g., sleep)
                    Container(
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
                      child: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: 16,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => _onCardTap(index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _revealed[index] ? Colors.transparent : Colors.grey[400],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: _revealed[index]
                              ? Image.asset(
                                  'assets/img/${_images[index]}.png',
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : const SizedBox(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_gameFinished)
                Column(
                  children: [
                    const Text(
                      "🗡️ The sword has been returned!",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton(
                      onPressed: _goToMain,
                      child: const Text("Return to Main Page"),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}