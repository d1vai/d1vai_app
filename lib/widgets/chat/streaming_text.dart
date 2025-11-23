import 'dart:async';
import 'package:flutter/material.dart';

/// Streaming text widget that types out text character by character
class StreamingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration? animationDuration;
  final VoidCallback? onComplete;
  final bool isMarkdown;

  const StreamingText({
    super.key,
    required this.text,
    this.style,
    this.animationDuration,
    this.onComplete,
    this.isMarkdown = true,
  });

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText> {
  String _displayedText = '';
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    if (widget.text.isEmpty) {
      setState(() {
        _displayedText = '';
      });
      widget.onComplete?.call();
      return;
    }

    final duration = widget.animationDuration ??
        Duration(milliseconds: (widget.text.length * 30));

    final interval = duration.inMilliseconds ~/ widget.text.length;

    _timer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayedText = widget.text.substring(0, _currentIndex + 1);
          _currentIndex++;
        });
      } else {
        timer.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.text != oldWidget.text) {
      _timer?.cancel();
      setState(() {
        _displayedText = '';
        _currentIndex = 0;
      });
      _startAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMarkdown) {
      // For streaming text, we can't use MarkdownText as it parses the full text
      // So we'll use regular text with some basic formatting detection
      return _buildFormattedText(_displayedText, widget.style);
    }

    return Text(
      _displayedText,
      style: widget.style,
    );
  }

  Widget _buildFormattedText(String text, TextStyle? baseStyle) {
    // Simple markdown-like formatting for streaming text
    List<TextSpan> spans = [];

    // Bold detection: **text**
    final boldRegex = RegExp(r'\*\*([^*]+)\*\*');
    final boldMatches = boldRegex.allMatches(text).toList();

    // Italic detection: *text*
    final italicRegex = RegExp(r'\*([^*]+)\*');
    final italicMatches = italicRegex.allMatches(text).toList();

    // Inline code: `code`
    final codeRegex = RegExp(r'`([^`]+)`');
    final codeMatches = codeRegex.allMatches(text).toList();

    List<RegExpMatch> allMatches = [
      ...boldMatches,
      ...italicMatches,
      ...codeMatches,
    ];

    allMatches.sort((a, b) => a.start.compareTo(b.start));

    int cursor = 0;

    for (var match in allMatches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start), style: baseStyle));
      }

      String matched = match.group(0)!;

      if (matched.startsWith('**')) {
        spans.add(TextSpan(
          text: match.group(1)!,
          style: baseStyle?.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (matched.startsWith('*') && !matched.startsWith('**')) {
        spans.add(TextSpan(
          text: match.group(1)!,
          style: baseStyle?.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (matched.startsWith('`')) {
        spans.add(TextSpan(
          text: match.group(1)!,
          style: baseStyle?.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey[300],
          ),
        ));
      }
      
      cursor = match.end;
    }
    
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
