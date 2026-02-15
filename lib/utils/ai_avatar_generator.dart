/// Avatar style options for AI-generated avatars
enum AvatarStyle { micah, lorelei, adventurer, personas, bigSmile, avataaars }

/// Options for generating AI avatars
class AvatarOptions {
  final int? size;
  final bool? consistent;
  final AvatarStyle? style;

  const AvatarOptions({this.size, this.consistent, this.style});

  AvatarOptions copyWith({int? size, bool? consistent, AvatarStyle? style}) {
    return AvatarOptions(
      size: size ?? this.size,
      consistent: consistent ?? this.consistent,
      style: style ?? this.style,
    );
  }
}

/// Advanced avatar generator using DiceBear API.
/// Provides stable styles per username while allowing random draws.
class AiAvatarGenerator {
  final Map<String, AvatarStyle> _styleMap = {};
  static const String _baseUrl = 'https://api.dicebear.com/7.x';

  /// Available avatar styles
  static const List<AvatarStyle> _styles = [
    AvatarStyle.micah,
    AvatarStyle.lorelei,
    AvatarStyle.adventurer,
    AvatarStyle.personas,
    AvatarStyle.bigSmile,
    AvatarStyle.avataaars,
  ];

  /// Generate avatar URL for a seed string.
  ///
  /// [seed] - The seed string (usually username or unique identifier)
  /// [options] - Generation options (size, consistency, style)
  String generateAvatar(
    String seed, {
    AvatarOptions options = const AvatarOptions(),
  }) {
    final size = options.size ?? 160;
    final consistent = options.consistent ?? true;
    final customStyle = options.style;

    AvatarStyle style;

    // If style is explicitly specified, respect it
    if (customStyle != null) {
      style = customStyle;
    } else if (consistent) {
      // Stable style assignment per seed
      if (_styleMap.containsKey(seed)) {
        style = _styleMap[seed]!;
      } else {
        style = _assignStyle(seed);
      }
    } else {
      // Pure random style (used for AI draw / gacha)
      final idx = (DateTime.now().millisecondsSinceEpoch % _styles.length);
      style = _styles[idx];
    }

    return _buildAvatarUrl(seed, style, size);
  }

  /// Assign a deterministic style for a seed string.
  AvatarStyle _assignStyle(String seed) {
    final hash = _stringToHash(seed);
    final style = _styles[hash % _styles.length];
    _styleMap[seed] = style;
    return style;
  }

  /// Simple string hash function.
  int _stringToHash(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      final char = str.codeUnitAt(i);
      hash = (hash << 5) - hash + char;
      hash = hash & hash; // Convert to 32bit integer
    }
    return hash.abs();
  }

  /// Build full avatar URL.
  String _buildAvatarUrl(String seed, AvatarStyle style, int size) {
    final styleString = _styleToString(style);
    final params = {'seed': seed, 'size': size.toString()};

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_baseUrl/$styleString/svg?$queryString';
  }

  /// Convert enum to string for API calls
  String _styleToString(AvatarStyle style) {
    switch (style) {
      case AvatarStyle.micah:
        return 'micah';
      case AvatarStyle.lorelei:
        return 'lorelei';
      case AvatarStyle.adventurer:
        return 'adventurer';
      case AvatarStyle.personas:
        return 'personas';
      case AvatarStyle.bigSmile:
        return 'big-smile';
      case AvatarStyle.avataaars:
        return 'avataaars';
    }
  }

  /// Get the style associated with a seed (for debugging)
  AvatarStyle? getUserStyle(String seed) {
    return _styleMap[seed];
  }

  /// Clear the style cache
  void clearCache() {
    _styleMap.clear();
  }

  /// Generate multiple avatars at once for AI draw functionality
  ///
  /// [baseSeed] - Base seed for generation
  /// [count] - Number of avatars to generate
  /// [size] - Avatar size
  List<String> generateMultipleAvatars(
    String baseSeed,
    int count, {
    int size = 160,
  }) {
    final avatars = <String>[];
    for (int i = 0; i < count; i++) {
      final seed =
          '$baseSeed-${DateTime.now().millisecondsSinceEpoch}-$i-${(DateTime.now().microsecondsSinceEpoch % 100000).toString()}';
      avatars.add(
        generateAvatar(
          seed,
          options: AvatarOptions(size: size, consistent: false),
        ),
      );
    }
    return avatars;
  }
}

/// Convenience instance for simple usage
final aiAvatarGenerator = AiAvatarGenerator();
