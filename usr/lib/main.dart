import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monster Jump Adventure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  
  // Game State
  bool isPlaying = false;
  bool isGameOver = false;
  double score = 0;
  
  // Physics Constants
  final double gravity = 0.6;
  final double jumpForce = -16.0;
  final double platformWidth = 80.0;
  final double platformHeight = 20.0;
  
  // Entities
  Monster monster = Monster(x: 0, y: 0, dx: 0, dy: 0);
  List<Platform> platforms = [];
  
  // Screen Dimensions
  double screenWidth = 0;
  double screenHeight = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    // Start the game loop immediately, but game logic waits for start
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    
    if (!isPlaying && !isGameOver) {
      _resetGame();
    }
  }

  void _resetGame() {
    monster = Monster(
      x: screenWidth / 2,
      y: screenHeight / 2,
      dx: 0,
      dy: 0,
    );
    
    platforms.clear();
    // Create initial platforms
    double currentY = screenHeight;
    while (currentY > 0) {
      platforms.add(Platform(
        x: Random().nextDouble() * (screenWidth - platformWidth),
        y: currentY,
        w: platformWidth,
        h: platformHeight,
        type: PlatformType.normal,
      ));
      currentY -= 100; // Gap between platforms
    }
    
    score = 0;
    isGameOver = false;
    setState(() {});
  }

  void _startGame() {
    setState(() {
      isPlaying = true;
      isGameOver = false;
      _resetGame();
      monster.dy = jumpForce; // Initial jump
      if (!_ticker.isActive) _ticker.start();
    });
  }

  void _onTick(Duration elapsed) {
    if (!isPlaying || isGameOver) return;

    setState(() {
      _updatePhysics();
    });
  }

  void _updatePhysics() {
    // Apply Gravity
    monster.dy += gravity;
    monster.y += monster.dy;

    // Horizontal movement (tilt control simulation or auto-bounce logic could go here)
    // For this simple version, we'll keep horizontal fixed or add tap-to-move later.
    // Let's make it simple: Tap left/right side of screen to move? 
    // Or just automatic jumping. Let's implement simple left/right movement based on touch position later.
    // For now, let's add simple wrapping
    if (monster.x < -20) monster.x = screenWidth;
    if (monster.x > screenWidth) monster.x = -20;

    // Camera / World Scrolling (Monster goes up)
    if (monster.y < screenHeight / 2 && monster.dy < 0) {
      double offset = -monster.dy;
      monster.y += offset; // Keep monster in place
      score += offset; // Score based on height
      
      // Move platforms down
      for (var p in platforms) {
        p.y += offset;
      }
      
      // Remove platforms off screen
      platforms.removeWhere((p) => p.y > screenHeight);
      
      // Add new platforms at top
      Platform lastPlatform = platforms.lastWhere((p) => true, orElse: () => Platform(x: 0, y: 0, w: 0, h: 0, type: PlatformType.normal));
      // Find the highest platform (smallest y)
      double highestY = screenHeight;
      if (platforms.isNotEmpty) {
        highestY = platforms.map((p) => p.y).reduce(min);
      }
      
      if (highestY > 50) {
         platforms.add(Platform(
          x: Random().nextDouble() * (screenWidth - platformWidth),
          y: highestY - (80 + Random().nextDouble() * 40), // Random gap
          w: platformWidth,
          h: platformHeight,
          type: Random().nextDouble() > 0.9 ? PlatformType.moving : PlatformType.normal,
        ));
      }
    }

    // Collision Detection (Only when falling)
    if (monster.dy > 0) {
      for (var p in platforms) {
        if (monster.x + 40 > p.x && 
            monster.x - 40 < p.x + p.w &&
            monster.y + 40 > p.y &&
            monster.y + 40 < p.y + p.h + 20) { // +20 tolerance
          
          monster.dy = jumpForce;
          // Play sound effect here
          break;
        }
      }
    }

    // Game Over Condition
    if (monster.y > screenHeight) {
      isGameOver = true;
      isPlaying = false;
      _ticker.stop();
    }
    
    // Update moving platforms
    for (var p in platforms) {
      if (p.type == PlatformType.moving) {
        p.x += 2; // Simple movement
        if (p.x > screenWidth) p.x = -platformWidth;
      }
    }
  }

  void _handleTap(TapUpDetails details) {
    if (isGameOver) {
      _startGame();
      return;
    }
    
    if (!isPlaying) {
      _startGame();
      return;
    }

    // Simple control: Tap left side to move left, right side to move right
    // Or simpler: The monster jumps automatically, tap to boost? 
    // The prompt says "Tap screen to make monster jump".
    // Usually these games are "Doodle Jump" style (tilt to move, auto jump) OR "Flappy" style.
    // Prompt says: "Tap to make monster jump". This implies manual jumping or double jumping?
    // "Timing is key - land safely".
    // Let's implement: Monster moves horizontally automatically or via tilt? 
    // Let's do: Tap moves the monster towards the tap X position horizontally.
    
    double targetX = details.localPosition.dx;
    // Simple interpolation towards tap
    monster.x = targetX;
  }
  
  void _handlePan(DragUpdateDetails details) {
    if (isPlaying && !isGameOver) {
      monster.x += details.delta.dx;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTapUp: _handleTap,
        onHorizontalDragUpdate: _handlePan,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF87CEEB), Color(0xFFE0F7FA)], // Sky colors
            ),
          ),
          child: Stack(
            children: [
              // Game Renderer
              CustomPaint(
                painter: GamePainter(monster, platforms, score),
                size: Size.infinite,
              ),
              
              // UI Overlay
              if (!isPlaying && !isGameOver)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "JUMP ADVENTURE",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 10, color: Colors.black45, offset: Offset(2, 2))],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _startGame,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("START GAME", style: TextStyle(fontSize: 24)),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text("Drag to move left/right", style: TextStyle(color: Colors.white70)),
                      )
                    ],
                  ),
                ),

              if (isGameOver)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("GAME OVER", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.red)),
                        Text("Score: ${score.toInt()}", style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _startGame,
                          child: const Text("TRY AGAIN"),
                        ),
                      ],
                    ),
                  ),
                ),
                
              // Score Display
              Positioned(
                top: 40,
                left: 20,
                child: Text(
                  "Score: ${score.toInt()}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 5, color: Colors.black)],
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

// --- Game Entities ---

enum PlatformType { normal, moving, breakable }

class Platform {
  double x;
  double y;
  double w;
  double h;
  PlatformType type;

  Platform({required this.x, required this.y, required this.w, required this.h, required this.type});
}

class Monster {
  double x;
  double y;
  double dx;
  double dy;

  Monster({required this.x, required this.y, required this.dx, required this.dy});
}

// --- Rendering ---

class GamePainter extends CustomPainter {
  final Monster monster;
  final List<Platform> platforms;
  final double score;

  GamePainter(this.monster, this.platforms, this.score);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Platforms
    final Paint platformPaint = Paint()..color = Colors.green;
    final Paint movingPlatformPaint = Paint()..color = Colors.blue;
    
    for (var p in platforms) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x, p.y, p.w, p.h),
          const Radius.circular(10),
        ),
        p.type == PlatformType.moving ? movingPlatformPaint : platformPaint,
      );
      
      // Add some detail to platform (grass top)
      final Paint grassPaint = Paint()..color = Colors.lightGreenAccent;
      canvas.drawRect(Rect.fromLTWH(p.x, p.y, p.w, 5), grassPaint);
    }

    // Draw Monster
    final Paint monsterBody = Paint()..color = Colors.purpleAccent;
    final Paint monsterEye = Paint()..color = Colors.white;
    final Paint monsterPupil = Paint()..color = Colors.black;

    // Body
    canvas.drawCircle(Offset(monster.x, monster.y), 20, monsterBody);
    
    // Eyes
    canvas.drawCircle(Offset(monster.x - 8, monster.y - 5), 6, monsterEye);
    canvas.drawCircle(Offset(monster.x + 8, monster.y - 5), 6, monsterEye);
    
    // Pupils (look in direction of movement or center)
    canvas.drawCircle(Offset(monster.x - 8, monster.y - 5), 2, monsterPupil);
    canvas.drawCircle(Offset(monster.x + 8, monster.y - 5), 2, monsterPupil);
    
    // Mouth
    final Paint mouthPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(monster.x, monster.y + 5), width: 10, height: 10),
      0.1,
      3.0,
      false,
      mouthPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
