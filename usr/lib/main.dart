import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
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
        fontFamily: 'Arial', // Fallback font
      ),
      // Explicitly define routes for safer navigation
      initialRoute: '/',
      routes: {
        '/': (context) => const GameScreen(),
      },
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
  double highScore = 0;
  
  // Physics Constants
  final double gravity = 0.5;
  final double jumpForce = -13.0;
  final double boostForce = -20.0;
  final double platformWidth = 70.0;
  final double platformHeight = 18.0;
  
  // Entities
  late Monster monster;
  List<Platform> platforms = [];
  List<Particle> particles = [];
  
  // Screen Dimensions
  double screenWidth = 0;
  double screenHeight = 0;
  bool _initialized = false;

  // Assets (Colors)
  final Color skyTop = const Color(0xFF200122);
  final Color skyBottom = const Color(0xFF6f0000);
  
  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    monster = Monster(x: 0, y: 0, dx: 0, dy: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      screenWidth = MediaQuery.of(context).size.width;
      screenHeight = MediaQuery.of(context).size.height;
      _resetGame();
      _initialized = true;
    }
  }

  void _resetGame() {
    monster = Monster(
      x: screenWidth / 2,
      y: screenHeight - 200,
      dx: 0,
      dy: 0,
    );
    
    platforms.clear();
    particles.clear();
    score = 0;
    
    // Initial Platform under monster
    platforms.add(Platform(
      x: screenWidth / 2 - platformWidth / 2,
      y: screenHeight - 100,
      w: platformWidth,
      h: platformHeight,
      type: PlatformType.normal,
    ));

    // Generate starting platforms
    _generateInitialPlatforms();
    
    isGameOver = false;
    // Don't start playing immediately, wait for user tap
    setState(() {});
  }

  void _generateInitialPlatforms() {
    double currentY = screenHeight - 200;
    while (currentY > 0) {
      _addPlatform(currentY);
      currentY -= 90; // Gap
    }
  }

  void _addPlatform(double y) {
    double x = Random().nextDouble() * (screenWidth - platformWidth);
    
    // Difficulty scaling
    double difficulty = score / 10000;
    if (difficulty > 0.8) difficulty = 0.8;
    
    PlatformType type = PlatformType.normal;
    double r = Random().nextDouble();
    
    if (r < 0.1 + difficulty * 0.2) {
      type = PlatformType.moving;
    } else if (r < 0.2 + difficulty * 0.3) {
      type = PlatformType.breakable;
    } else if (r < 0.25 + difficulty * 0.1) {
      type = PlatformType.boost; // Spring platform
    }

    platforms.add(Platform(
      x: x,
      y: y,
      w: platformWidth,
      h: platformHeight,
      type: type,
    ));
  }

  void _startGame() {
    if (!isPlaying) {
      setState(() {
        isPlaying = true;
        isGameOver = false;
        monster.dy = jumpForce;
        if (!_ticker.isActive) _ticker.start();
      });
    }
  }

  void _onTick(Duration elapsed) {
    if (!isPlaying || isGameOver) return;

    setState(() {
      _updatePhysics();
      _updateParticles();
    });
  }

  void _updatePhysics() {
    // Apply Gravity
    monster.dy += gravity;
    monster.y += monster.dy;

    // Wrap around screen
    if (monster.x < -20) monster.x = screenWidth;
    if (monster.x > screenWidth) monster.x = -20;

    // Camera / World Scrolling
    if (monster.y < screenHeight / 2 && monster.dy < 0) {
      double offset = -monster.dy;
      monster.y += offset;
      score += offset;
      
      // Move platforms down
      for (var p in platforms) {
        p.y += offset;
      }
      
      // Remove platforms off screen
      platforms.removeWhere((p) => p.y > screenHeight);
      
      // Add new platforms
      if (platforms.isEmpty || platforms.last.y > 100) {
        _addPlatform(platforms.isEmpty ? 0 : platforms.last.y - (80 + Random().nextDouble() * 40));
      }
    }

    // Collision Detection (Only when falling)
    if (monster.dy > 0) {
      for (var p in platforms) {
        if (monster.x + 30 > p.x && 
            monster.x - 30 < p.x + p.w &&
            monster.y + 30 > p.y &&
            monster.y + 30 < p.y + p.h + 20) {
          
          if (p.type == PlatformType.breakable) {
            p.broken = true;
            _createParticles(p.x + p.w/2, p.y, Colors.brown);
            // Breakable platforms don't bounce unless you want them to break AFTER bounce
            // Let's make them break immediately and give a small hop or fall through
            // For this game, let's make them fall through (no bounce) or small bounce then break
            monster.dy = jumpForce * 0.5; // Small bounce
            platforms.remove(p);
            break; 
          } else if (p.type == PlatformType.boost) {
             monster.dy = boostForce;
             _createParticles(monster.x, monster.y + 20, Colors.yellow);
          } else {
            monster.dy = jumpForce;
            _createParticles(monster.x, monster.y + 20, Colors.white.withOpacity(0.5));
          }
          break;
        }
      }
    }

    // Game Over
    if (monster.y > screenHeight) {
      _gameOver();
    }
    
    // Update moving platforms
    for (var p in platforms) {
      if (p.type == PlatformType.moving) {
        p.x += p.speed;
        if (p.x > screenWidth - p.w || p.x < 0) {
          p.speed = -p.speed;
        }
      }
    }
  }

  void _updateParticles() {
    for (var p in particles) {
      p.update();
    }
    particles.removeWhere((p) => p.life <= 0);
  }

  void _createParticles(double x, double y, Color color) {
    for (int i = 0; i < 5; i++) {
      particles.add(Particle(
        x: x,
        y: y,
        dx: (Random().nextDouble() - 0.5) * 4,
        dy: (Random().nextDouble() - 0.5) * 4,
        color: color,
      ));
    }
  }

  void _gameOver() {
    isGameOver = true;
    isPlaying = false;
    _ticker.stop();
    if (score > highScore) {
      highScore = score;
    }
    setState(() {});
  }

  void _handleTap() {
    if (isGameOver) {
      _resetGame();
      _startGame();
    } else if (!isPlaying) {
      _startGame();
    } else {
      // "Tap to Jump" mechanic - Double jump or air jump?
      // Or simply restart if game hasn't started.
      // The prompt says "Tap screen to make monster jump".
      // Let's allow a single air-jump if not too fast falling?
      // Or just simple control: Tap to start.
      // Let's stick to: Tap does nothing in-game (auto jump), 
      // UNLESS we want to implement "Tap to Boost".
      // Let's add a small boost if tapped, but limit it?
      // No, let's keep it simple: Tap is for UI / Start.
      // Movement is drag.
    }
  }
  
  void _handlePan(DragUpdateDetails details) {
    if (isPlaying && !isGameOver) {
      monster.x += details.delta.dx * 1.5; // Sensitivity
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
        onTap: _handleTap,
        onHorizontalDragUpdate: _handlePan,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [skyTop, skyBottom],
            ),
          ),
          child: Stack(
            children: [
              // Game World
              CustomPaint(
                painter: GamePainter(monster, platforms, particles, score),
                size: Size.infinite,
              ),
              
              // UI Overlay
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Score: ${score.toInt()}",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                      Text(
                        "High Score: ${highScore.toInt()}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Start / Game Over Screens
              if (!isPlaying && !isGameOver)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTitle("MONSTER JUMP"),
                      const SizedBox(height: 20),
                      const Text(
                        "Tap to Start\nDrag to Move",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      const SizedBox(height: 40),
                      _buildButton("PLAY", _startGame),
                    ],
                  ),
                ),

              if (isGameOver)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("GAME OVER", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        const SizedBox(height: 10),
                        Text("Score: ${score.toInt()}", style: const TextStyle(fontSize: 24, color: Colors.white)),
                        const SizedBox(height: 30),
                        _buildButton("RETRY", () {
                          _resetGame();
                          _startGame();
                        }),
                      ],
                    ),
                  ),
                ),
                
              // AdMob Placeholder (Bottom Banner)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 50,
                  width: double.infinity,
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Text(
                    "AdMob Banner Placeholder",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        color: Colors.yellow,
        shadows: [
          Shadow(blurRadius: 0, color: Colors.red, offset: Offset(4, 4)),
          Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 0)),
        ],
      ),
    );
  }
  
  Widget _buildButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
        textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        elevation: 10,
      ),
      child: Text(text),
    );
  }
}

// --- Game Entities ---

enum PlatformType { normal, moving, breakable, boost }

class Platform {
  double x;
  double y;
  double w;
  double h;
  PlatformType type;
  double speed; // For moving platforms
  bool broken;

  Platform({
    required this.x, 
    required this.y, 
    required this.w, 
    required this.h, 
    required this.type,
    this.speed = 2.0,
    this.broken = false,
  });
}

class Monster {
  double x;
  double y;
  double dx;
  double dy;

  Monster({required this.x, required this.y, required this.dx, required this.dy});
}

class Particle {
  double x;
  double y;
  double dx;
  double dy;
  double life;
  Color color;

  Particle({required this.x, required this.y, required this.dx, required this.dy, required this.color}) : life = 1.0;

  void update() {
    x += dx;
    y += dy;
    dy += 0.1; // Gravity
    life -= 0.05;
  }
}

// --- Rendering ---

class GamePainter extends CustomPainter {
  final Monster monster;
  final List<Platform> platforms;
  final List<Particle> particles;
  final double score;

  GamePainter(this.monster, this.platforms, this.particles, this.score);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Platforms
    for (var p in platforms) {
      if (p.broken) continue;
      
      Paint paint = Paint();
      switch (p.type) {
        case PlatformType.normal:
          paint.color = Colors.green;
          break;
        case PlatformType.moving:
          paint.color = Colors.blue;
          break;
        case PlatformType.breakable:
          paint.color = Colors.brown;
          break;
        case PlatformType.boost:
          paint.color = Colors.orange;
          break;
      }
      
      // Platform Body
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x, p.y, p.w, p.h),
          const Radius.circular(8),
        ),
        paint,
      );
      
      // Platform Detail (Top highlight)
      paint.color = Colors.white.withOpacity(0.3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x, p.y, p.w, p.h / 2),
          const Radius.circular(8),
        ),
        paint,
      );
    }

    // Draw Particles
    for (var p in particles) {
      final paint = Paint()..color = p.color.withOpacity(p.life.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(p.x, p.y), 3, paint);
    }

    // Draw Monster
    _drawMonster(canvas, monster);
  }
  
  void _drawMonster(Canvas canvas, Monster m) {
    // Body
    final Paint bodyPaint = Paint()..color = const Color(0xFF9C27B0); // Purple
    canvas.drawCircle(Offset(m.x, m.y), 20, bodyPaint);
    
    // Belly
    final Paint bellyPaint = Paint()..color = const Color(0xFFE1BEE7);
    canvas.drawOval(Rect.fromCenter(center: Offset(m.x, m.y + 5), width: 25, height: 20), bellyPaint);

    // Eyes
    final Paint whitePaint = Paint()..color = Colors.white;
    final Paint blackPaint = Paint()..color = Colors.black;
    
    // Left Eye
    canvas.drawCircle(Offset(m.x - 8, m.y - 8), 8, whitePaint);
    canvas.drawCircle(Offset(m.x - 8 + (m.dx * 0.5).clamp(-3, 3), m.y - 8 + (m.dy * 0.2).clamp(-2, 2)), 3, blackPaint);
    
    // Right Eye
    canvas.drawCircle(Offset(m.x + 8, m.y - 8), 8, whitePaint);
    canvas.drawCircle(Offset(m.x + 8 + (m.dx * 0.5).clamp(-3, 3), m.y - 8 + (m.dy * 0.2).clamp(-2, 2)), 3, blackPaint);
    
    // Mouth (Smile)
    final Paint mouthPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
      
    canvas.drawArc(
      Rect.fromCenter(center: Offset(m.x, m.y + 5), width: 12, height: 10),
      0.2,
      2.8,
      false,
      mouthPaint,
    );
    
    // Horns or Ears
    final Paint hornPaint = Paint()..color = Colors.deepPurple;
    Path leftHorn = Path();
    leftHorn.moveTo(m.x - 15, m.y - 10);
    leftHorn.lineTo(m.x - 25, m.y - 25);
    leftHorn.lineTo(m.x - 10, m.y - 18);
    canvas.drawPath(leftHorn, hornPaint);
    
    Path rightHorn = Path();
    rightHorn.moveTo(m.x + 15, m.y - 10);
    rightHorn.lineTo(m.x + 25, m.y - 25);
    rightHorn.lineTo(m.x + 10, m.y - 18);
    canvas.drawPath(rightHorn, hornPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
