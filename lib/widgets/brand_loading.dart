import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class BrandLoading extends StatefulWidget {
  final String brand;
  final List<String> tips;
  final Duration tipInterval;
  final VoidCallback? onComplete;
  final Color? accentColor;
  final bool showBackgroundMatrix;
  final double? width;
  final double? height;

  const BrandLoading({
    super.key,
    this.brand = 'D1V',
    this.tips = const [
      'Initializing runtime',
      'Linking services',
      'Preparing assets',
      'Syncing workspace',
      'Connecting to cloud',
      'Almost there…',
    ],
    this.tipInterval = const Duration(milliseconds: 1600),
    this.onComplete,
    this.accentColor,
    this.showBackgroundMatrix = true,
    this.width,
    this.height,
  });

  @override
  State<BrandLoading> createState() => _BrandLoadingState();
}

class _BrandLoadingState extends State<BrandLoading>
    with TickerProviderStateMixin {
  late List<String> _displayChars;
  late List<String> _targetChars;
  int _lockedCount = 0;
  int _tipIndex = 0;
  double _scanPosition = -0.1;
  final String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  late AnimationController _scanController;
  late Timer _scrambleTimer;
  late Timer _tipTimer;
  late Timer _lockTimer;
  final Random _random = Random();
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _targetChars = widget.brand.toUpperCase().split('');
    _displayChars = List.generate(_targetChars.length, (_) => _randomChar());

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 3600),
      vsync: this,
    );

    _scanController.addListener(() {
      setState(() {
        _scanPosition = _scanController.value;
      });
    });

    _scanController.repeat();

    _startScrambleAnimation();
    _startLockCharacters();
    _startTipRotation();

    _animationComplete();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _scrambleTimer.cancel();
    _tipTimer.cancel();
    _lockTimer.cancel();
    super.dispose();
  }

  void _animationComplete() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lockedCount >= _targetChars.length && !_isComplete) {
        _isComplete = true;
        widget.onComplete?.call();
      }
    });
  }

  void _startScrambleAnimation() {
    _scrambleTimer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      setState(() {
        _displayChars = List.generate(_targetChars.length, (index) {
          return index < _lockedCount ? _targetChars[index] : _randomChar();
        });
      });
    });
  }

  void _startLockCharacters() {
    _lockTimer = Timer(const Duration(milliseconds: 900), () {
      for (int i = 0; i < _targetChars.length; i++) {
        Timer(Duration(milliseconds: i * 500), () {
          setState(() {
            _lockedCount = min(_lockedCount + 1, _targetChars.length);
          });
          _animationComplete();
        });
      }
    });
  }

  void _startTipRotation() {
    _tipTimer = Timer.periodic(widget.tipInterval, (timer) {
      setState(() {
        _tipIndex = (_tipIndex + 1) % widget.tips.length;
      });
    });
  }

  String _randomChar() {
    return _alphabet[_random.nextInt(_alphabet.length)];
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? Colors.green.shade400;
    final screenSize = MediaQuery.of(context).size;
    final containerWidth = widget.width ?? min(screenSize.width * 0.6, 288);
    final containerHeight = widget.height ?? 160;

    return Center(
      child: Container(
        width: containerWidth,
        height: containerHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade800, width: 1),
          color: Colors.black87,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Scanning band animation
              if (_isVisible)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScanBandPainter(
                      scanPosition: _scanPosition,
                      color: accentColor,
                    ),
                  ),
                ),

              // Brand letters
              Center(
                child: SelectableText.rich(
                  TextSpan(
                    children: List.generate(_targetChars.length, (index) {
                      return TextSpan(
                        text: _displayChars[index],
                        style: TextStyle(
                          fontSize: 48,
                          fontFamily: 'monospace',
                          color: accentColor,
                          letterSpacing: 4,
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Tips area
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: _TipLine(
                  text: widget.tips[_tipIndex],
                  accentColor: accentColor,
                ),
              ),

              // Background matrix
              if (widget.showBackgroundMatrix)
                Positioned.fill(
                  child: _RandomMatrix(
                    density: 60,
                    color: accentColor.withValues(alpha: 0.1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isVisible => _scanPosition >= -0.1 && _scanPosition <= 1.1;
}

class _ScanBandPainter extends CustomPainter {
  final double scanPosition;
  final Color color;

  const _ScanBandPainter({
    required this.scanPosition,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Main scanning line
    final y = size.height * scanPosition;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      paint,
    );

    // Gradient blur effect
    final blurPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawRect(
      Rect.fromLTRB(0, y - 16, size.width, y + 16),
      blurPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanBandPainter oldDelegate) {
    return oldDelegate.scanPosition != scanPosition;
  }
}

class _TipLine extends StatefulWidget {
  final String text;
  final Color accentColor;

  const _TipLine({
    required this.text,
    required this.accentColor,
  });

  @override
  State<_TipLine> createState() => _TipLineState();
}

class _TipLineState extends State<_TipLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Timer(const Duration(milliseconds: 10), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(_TipLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: Offset(0, (1 - _animation.value) * 8),
        child: Opacity(
          opacity: _animation.value,
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _RandomMatrix extends StatefulWidget {
  final int density;
  final Color color;

  const _RandomMatrix({
    required this.density,
    required this.color,
  });

  @override
  State<_RandomMatrix> createState() => _RandomMatrixState();
}

class _RandomMatrixState extends State<_RandomMatrix>
    with SingleTickerProviderStateMixin {
  late List<String> _chars;
  late Timer _driftTimer;
  final Random _random = Random();
  final String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  @override
  void initState() {
    super.initState();
    _chars = List.generate(
      widget.density,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    );

    _driftTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() {
        for (int i = 0; i < (widget.density / 12).ceil(); i++) {
          final index = _random.nextInt(_chars.length);
          _chars[index] = _alphabet[_random.nextInt(_alphabet.length)];
        }
      });
    });
  }

  @override
  void dispose() {
    _driftTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.1,
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                runSpacing: 2,
                spacing: 4,
                children: _chars
                    .map((char) => Text(
                          char,
                          style: TextStyle(
                            fontSize: 8,
                            color: widget.color,
                            fontFamily: 'monospace',
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
