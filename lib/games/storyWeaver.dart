import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';

class StoryWeaverGame extends StatefulWidget {
  final int energy;
  final int coins;
  final Function(int, int) onGameComplete;

  const StoryWeaverGame({
    Key? key,
    required this.energy,
    required this.coins,
    required this.onGameComplete,
  }) : super(key: key);

  @override
  State<StoryWeaverGame> createState() => _StoryWeaverGameState();
}

class _StoryWeaverGameState extends State<StoryWeaverGame> {
  final TextEditingController _characterController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  String? _generatedStory;
  int? _storyRating;
  int _newCoins = 0;
  bool _isGenerating = false;
  bool _isSpeaking = false;

  // Placeholder Gemini API key (replace with actual key for real use)
  final String _apiKey = 'AI+++++++++++';

  @override
  void initState() {
    super.initState();
    _setupTts();
  }

  Future<void> _setupTts() async {
    await _flutterTts.setLanguage('vi-VN');
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  @override
  void dispose() {
    _characterController.dispose();
    _contextController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _generateStory() async {
    if (_characterController.text.isEmpty || _contextController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in both character and context!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    if (widget.energy < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough energy! Need 10%.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    String character = _characterController.text;
    String storyContext = _contextController.text;

    // Context for Gemini API to ensure Vietnamese folklore style
    const String promptContext = '''
You are a storyteller specializing in Vietnamese folklore, inspired by tales like those performed in water puppetry. Create a short story (200–300 words) featuring the provided character and context. The story should include traditional elements like mystical creatures (dragons, spirits), settings (Red River, Hoan Kiem Lake, bamboo forests), and themes of courage, wisdom, or harmony. Use a narrative style suitable for a mobile game, engaging and concise, with a clear beginning, challenge, and resolution.
''';

    String fullPrompt = '''
$promptContext

Character: $character
Context: $storyContext

Story:
''';

    String story;
    try {
      // Call Gemini API (gemini-1.5-flash)
      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': fullPrompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        story = data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        // Fallback to gemini-pro if flash fails
        final fallbackResponse = await http.post(
          Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': fullPrompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.7,
              'topK': 40,
              'topP': 0.95,
              'maxOutputTokens': 1024,
            }
          }),
        );

        if (fallbackResponse.statusCode == 200) {
          final data = jsonDecode(fallbackResponse.body);
          story = data['candidates'][0]['content']['parts'][0]['text'];
        } else {
          // Fallback to mock story if both API calls fail
          story = _createMockStory(character, storyContext);
        }
      }
    } catch (e) {
      // Fallback to mock story on network or other errors
      story = _createMockStory(character, storyContext);
    }

    int rating = _rateStory(story);
    int coinReward = _calculateCoinReward(rating);

    setState(() {
      _generatedStory = story;
      _storyRating = rating;
      _newCoins = widget.coins + coinReward;
      _isGenerating = false;
    });

    // Update energy and coins
    widget.onGameComplete(widget.energy - 10, _newCoins);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Story generated! Earned $coinReward coins.'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green.shade600,
      ),
    );
  }

  Future<void> _readStoryAloud() async {
    if (_generatedStory == null || _isSpeaking) return;
    setState(() {
      _isSpeaking = true;
    });
    await _flutterTts.speak(_generatedStory!);
  }

  Future<void> _stopReading() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  String _createMockStory(String character, String storyContext) {
    List<String> beginnings = [
      'Long ago, in a misty village by the Red River,',
      'Under the ancient banyan tree of Hoan Kiem Lake,',
      'In the heart of a bamboo forest, blessed by spirits,',
    ];
    List<String> challenges = [
      'a wicked serpent demanded tribute from the villagers.',
      'a lost artifact of the Golden Turtle God needed to be found.',
      'an ancient curse threatened the land’s prosperity.',
    ];
    List<String> resolutions = [
      'With courage, $character restored peace and was hailed as a hero.',
      'Guided by the spirits, $character saved the village and earned eternal gratitude.',
      'Through wisdom and bravery, $character lifted the curse, bringing joy to all.',
    ];

    Random rand = Random();
    String beginning = beginnings[rand.nextInt(beginnings.length)];
    String challenge = challenges[rand.nextInt(challenges.length)];
    String resolution = resolutions[rand.nextInt(resolutions.length)];

    return '''
$beginning there lived $character. Known for their bravery, they faced a great trial when $storyContext $challenge
Using their wits and heart, $character embarked on a journey through mystical lands, meeting spirits and overcoming trials. $resolution
The tale of $character is still sung in the village, a reminder of courage and wisdom.
'''.trim();
  }

  int _rateStory(String story) {
    int lengthScore = (story.length / 600 * 30).clamp(0, 30).toInt();
    int coherenceScore = story.split('.').length > 5 ? 40 : 30;
    int culturalScore = (story.contains('Red River') ||
            story.contains('Hoan Kiem') ||
            story.contains('bamboo') ||
            story.contains('dragon') ||
            story.contains('spirit'))
        ? 30
        : 20;

    return (lengthScore + coherenceScore + culturalScore).clamp(0, 100);
  }

  int _calculateCoinReward(int rating) {
    if (rating <= 50) return 50;
    if (rating <= 75) return 100;
    return 150;
  }

  void _goToMain() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7FB069), Color(0xFF2F5233)],
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
                      onTap: _goToMain,
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
                      'Story Weaver',
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
                child: SingleChildScrollView(
                  child: _generatedStory == null
                      ? _buildInputForm()
                      : _buildStoryDisplay(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Craft Your Tale',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _characterController,
            decoration: InputDecoration(
              labelText: 'Describe Your Character (e.g., brave farmer An)',
              labelStyle: TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            style: TextStyle(color: Colors.white),
            maxLength: 50,
          ),
          SizedBox(height: 16),
          TextField(
            controller: _contextController,
            decoration: InputDecoration(
              labelText: 'Set the Story Context (e.g., a haunted village)',
              labelStyle: TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            style: TextStyle(color: Colors.white),
            maxLength: 50,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generateStory,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade400,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 8,
            ),
            child: _isGenerating
                ? CircularProgressIndicator(color: Colors.white)
                : Text(
                    'Weave Story (10% Energy)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryDisplay() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Tale',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Container(
            constraints: BoxConstraints(
              minHeight: 200,
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Text(
                _generatedStory!,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber.shade400, size: 24),
                SizedBox(width: 8),
                Text(
                  'Story Rating: $_storyRating/100',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _isSpeaking ? _stopReading : _readStoryAloud,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade400,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 8,
              ),
              child: Text(
                _isSpeaking ? 'Stop Reading' : 'Read Aloud',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _goToMain,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade400,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 8,
              ),
              child: Text(
                'Return to Main Page',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}