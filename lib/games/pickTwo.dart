// lib/games/pickTwo.dart
import 'package:flutter/material.dart';

class PickTwoGame extends StatefulWidget {
  const PickTwoGame({Key? key}) : super(key: key);

  @override
  State<PickTwoGame> createState() => _PickTwoGameState();
}

class _PickTwoGameState extends State<PickTwoGame> {
  final List<int> _numbers = List.generate(8, (i) => i + 1)..addAll(List.generate(8, (i) => i + 1))..shuffle();
  List<bool> _revealed = List.filled(16, false);
  List<int> _selectedIndices = [];
  bool _gameFinished = false;

  void _onCardTap(int index) {
    if (_revealed[index] || _selectedIndices.length == 2) return;

    setState(() {
      _revealed[index] = true;
      _selectedIndices.add(index);

      if (_selectedIndices.length == 2) {
        Future.delayed(const Duration(milliseconds: 700), () {
          final a = _selectedIndices[0];
          final b = _selectedIndices[1];

          if (_numbers[a] != _numbers[b]) {
            setState(() {
              _revealed[a] = false;
              _revealed[b] = false;
            });
          } else {
            // Check win
            if (!_revealed.contains(false)) {
              setState(() {
                _gameFinished = true;
              });
            }
          }
          _selectedIndices.clear();
        });
      }
    });
  }

  void _goToMain(BuildContext context) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pick Two")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_gameFinished)
            Column(
              children: [
                const Text(
                  "🗡️ The sword has been returned!",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () => _goToMain(context),
                  child: const Text("Return to Main Page"),
                ),
              ],
            )
          else
            Padding(
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
                        color: _revealed[index] ? Colors.blue[300] : Colors.grey[400],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _revealed[index] ? '${_numbers[index]}' : '?',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
