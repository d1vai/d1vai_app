class CodeTabFileNode {
  final String name;
  final bool isDirectory;
  final int? size;
  final List<CodeTabFileNode>? children;

  const CodeTabFileNode({
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.children,
  });

  factory CodeTabFileNode.fromJson(Map<String, dynamic> json) {
    return CodeTabFileNode(
      name: (json['name'] ?? '').toString(),
      isDirectory: json['is_directory'] == true,
      size: (json['size'] is int) ? json['size'] as int : null,
      children: (json['children'] is List)
          ? (json['children'] as List)
                .whereType<Map>()
                .map((e) => CodeTabFileNode.fromJson(e.cast<String, dynamic>()))
                .toList(growable: false)
          : null,
    );
  }
}

class CodeTabFlatNode {
  final CodeTabFileNode node;
  final String path;
  final int depth;

  const CodeTabFlatNode({
    required this.node,
    required this.path,
    required this.depth,
  });
}

class CodeTabFileContent {
  final String path;
  final String content;
  final int size;
  final bool isBinary;

  const CodeTabFileContent({
    required this.path,
    required this.content,
    required this.size,
    required this.isBinary,
  });

  factory CodeTabFileContent.fromJson(Map<String, dynamic> json) {
    return CodeTabFileContent(
      path: (json['path'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      size: (json['size'] is int) ? json['size'] as int : 0,
      isBinary: json['is_binary'] == true,
    );
  }
}
