import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' as hi;

class AppHighlightView extends StatelessWidget {
  final String text;
  final String language;
  final Map<String, TextStyle> theme;
  final TextStyle textStyle;

  const AppHighlightView({
    super.key,
    required this.text,
    required this.language,
    required this.theme,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final result = hi.highlight.parse(text, language: language);
    final root = theme['root'] ?? textStyle;
    final span = TextSpan(
      style: root.merge(textStyle),
      children: _buildChildren(result.nodes ?? const <hi.Node>[], root),
    );
    return RichText(text: span);
  }

  List<InlineSpan> _buildChildren(List<hi.Node> nodes, TextStyle inherited) {
    return nodes
        .map((node) => _buildNode(node, inherited))
        .toList(growable: false);
  }

  InlineSpan _buildNode(hi.Node node, TextStyle inherited) {
    final style = theme[node.className] ?? inherited;
    if (node.children != null && node.children!.isNotEmpty) {
      return TextSpan(
        text: node.value,
        style: style.merge(textStyle),
        children: _buildChildren(node.children!, style),
      );
    }
    return TextSpan(text: node.value, style: style.merge(textStyle));
  }
}
