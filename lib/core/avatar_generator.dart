import 'dart:math';

/// Available avatar styles, mirroring the web implementation.
enum AvatarStyle { micah, lorelei, adventurer, personas, bigSmile, avataaars }

/// Advanced avatar generator using DiceBear.
/// Provides stable styles per username while allowing random draws.
class DeveloperAvatarGenerator {
  final Map<String, AvatarStyle> _styleMap = <String, AvatarStyle>{};
  final Random _random;

  DeveloperAvatarGenerator({Random? random}) : _random = random ?? Random();

  /// Generate avatar URL for a username.
  String generateAvatar(
    String username, {
    int size = 80,
    bool consistent = true,
    AvatarStyle? style,
  }) {
    final AvatarStyle effectiveStyle;

    if (style != null) {
      effectiveStyle = style;
    } else if (consistent) {
      effectiveStyle = _getOrAssignStyle(username);
    } else {
      effectiveStyle = _randomStyle();
    }

    return _buildAvatarUrl(username, effectiveStyle, size);
  }

  AvatarStyle _getOrAssignStyle(String username) {
    final existing = _styleMap[username];
    if (existing != null) {
      return existing;
    }
    final hash = _stringToHash(username);
    final styles = AvatarStyle.values;
    final style = styles[hash % styles.length];
    _styleMap[username] = style;
    return style;
  }

  AvatarStyle _randomStyle() {
    final styles = AvatarStyle.values;
    return styles[_random.nextInt(styles.length)];
  }

  int _stringToHash(String str) {
    var hash = 0;
    for (var i = 0; i < str.length; i++) {
      final charCode = str.codeUnitAt(i);
      hash = (hash << 5) - hash + charCode;
      hash &= 0x7fffffff; // keep positive 32-bit
    }
    return hash;
  }

  String _buildAvatarUrl(String username, AvatarStyle style, int size) {
    final params = <String, String>{'seed': username, 'size': size.toString()};

    final stylePath = _styleToPath(style);
    final uri = Uri.https('api.dicebear.com', '/7.x/$stylePath/svg', params);
    return uri.toString();
  }

  String _styleToPath(AvatarStyle style) {
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

  /// For debugging: get the style associated with a username.
  AvatarStyle? getUserStyle(String username) => _styleMap[username];

  void clearCache() => _styleMap.clear();
}

// Convenience helper mirroring the web implementation's simple usage.
final DeveloperAvatarGenerator _defaultGenerator = DeveloperAvatarGenerator();

String generateDeveloperAvatar(String username, {int? size}) {
  if (size != null) {
    return _defaultGenerator.generateAvatar(username, size: size);
  }
  return _defaultGenerator.generateAvatar(username);
}
