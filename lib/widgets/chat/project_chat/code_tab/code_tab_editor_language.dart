import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/diff.dart';
import 'package:highlight/languages/dockerfile.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/gradle.dart';
import 'package:highlight/languages/graphql.dart';
import 'package:highlight/languages/ini.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/makefile.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/nginx.dart';
import 'package:highlight/languages/php.dart';
import 'package:highlight/languages/plaintext.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/shell.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/swift.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';

class CodeLanguageSupport {
  final Mode? mode;
  final String? highlightLanguage;

  const CodeLanguageSupport({
    required this.mode,
    required this.highlightLanguage,
  });
}

final CodeLanguageSupport _markdownSupport = CodeLanguageSupport(
  mode: markdown,
  highlightLanguage: 'markdown',
);
final CodeLanguageSupport _yamlSupport = CodeLanguageSupport(
  mode: yaml,
  highlightLanguage: 'yaml',
);
final CodeLanguageSupport _jsonSupport = CodeLanguageSupport(
  mode: json,
  highlightLanguage: 'json',
);
final CodeLanguageSupport _bashSupport = CodeLanguageSupport(
  mode: bash,
  highlightLanguage: 'bash',
);
final CodeLanguageSupport _shellSupport = CodeLanguageSupport(
  mode: shell,
  highlightLanguage: 'shell',
);
final CodeLanguageSupport _rubySupport = CodeLanguageSupport(
  mode: ruby,
  highlightLanguage: 'ruby',
);
final CodeLanguageSupport _dockerfileSupport = CodeLanguageSupport(
  mode: dockerfile,
  highlightLanguage: 'dockerfile',
);
final CodeLanguageSupport _makefileSupport = CodeLanguageSupport(
  mode: makefile,
  highlightLanguage: 'makefile',
);
final CodeLanguageSupport _nginxSupport = CodeLanguageSupport(
  mode: nginx,
  highlightLanguage: 'nginx',
);
final CodeLanguageSupport _gradleSupport = CodeLanguageSupport(
  mode: gradle,
  highlightLanguage: 'gradle',
);
final CodeLanguageSupport _graphqlSupport = CodeLanguageSupport(
  mode: graphql,
  highlightLanguage: 'graphql',
);
final CodeLanguageSupport _phpSupport = CodeLanguageSupport(
  mode: php,
  highlightLanguage: 'php',
);
final CodeLanguageSupport _plaintextSupport = CodeLanguageSupport(
  mode: plaintext,
  highlightLanguage: 'plaintext',
);
final CodeLanguageSupport _diffSupport = CodeLanguageSupport(
  mode: diff,
  highlightLanguage: 'diff',
);

CodeLanguageSupport? codeLanguageSupportForPath(String? path) {
  if (path == null || path.isEmpty) return null;
  final normalizedPath = path.replaceAll('\\', '/');
  final lowerPath = normalizedPath.toLowerCase();
  final fileName = normalizedPath.split('/').last;
  final lowerName = fileName.toLowerCase();

  switch (lowerName) {
    case 'dockerfile':
      return _dockerfileSupport;
    case 'makefile':
      return _makefileSupport;
    case 'podfile':
    case 'gemfile':
    case 'rakefile':
      return _rubySupport;
    case '.gitignore':
    case '.dockerignore':
    case '.editorconfig':
    case '.npmrc':
    case '.bashrc':
    case '.zshrc':
    case '.env':
    case '.env.local':
    case '.env.production':
    case '.env.development':
    case '.env.example':
      return _shellSupport;
    case 'nginx.conf':
      return _nginxSupport;
    case 'build.gradle':
    case 'build.gradle.kts':
    case 'settings.gradle':
    case 'settings.gradle.kts':
      return _gradleSupport;
    case 'package.json':
    case 'package-lock.json':
    case 'tsconfig.json':
    case 'composer.json':
      return _jsonSupport;
  }

  if (lowerPath.endsWith('.dart')) {
    return CodeLanguageSupport(mode: dart, highlightLanguage: 'dart');
  }
  if (lowerPath.endsWith('.kt') || lowerPath.endsWith('.kts')) {
    return CodeLanguageSupport(mode: kotlin, highlightLanguage: 'kotlin');
  }
  if (lowerPath.endsWith('.swift')) {
    return CodeLanguageSupport(mode: swift, highlightLanguage: 'swift');
  }
  if (lowerPath.endsWith('.ts') || lowerPath.endsWith('.tsx')) {
    return CodeLanguageSupport(
      mode: typescript,
      highlightLanguage: 'typescript',
    );
  }
  if (lowerPath.endsWith('.js') || lowerPath.endsWith('.jsx')) {
    return CodeLanguageSupport(
      mode: javascript,
      highlightLanguage: 'javascript',
    );
  }
  if (lowerPath.endsWith('.java')) {
    return CodeLanguageSupport(mode: java, highlightLanguage: 'java');
  }
  if (lowerPath.endsWith('.go')) {
    return CodeLanguageSupport(mode: go, highlightLanguage: 'go');
  }
  if (lowerPath.endsWith('.c') ||
      lowerPath.endsWith('.cc') ||
      lowerPath.endsWith('.cpp') ||
      lowerPath.endsWith('.cxx') ||
      lowerPath.endsWith('.h') ||
      lowerPath.endsWith('.hpp')) {
    return CodeLanguageSupport(mode: cpp, highlightLanguage: 'cpp');
  }
  if (lowerPath.endsWith('.json') ||
      lowerPath.endsWith('.jsonc') ||
      lowerPath.endsWith('.har')) {
    return _jsonSupport;
  }
  if (lowerPath.endsWith('.toml') ||
      lowerPath.endsWith('.ini') ||
      lowerPath.endsWith('.cfg') ||
      lowerPath.endsWith('.conf')) {
    return CodeLanguageSupport(mode: ini, highlightLanguage: 'ini');
  }
  if (lowerPath.endsWith('.md') ||
      lowerPath.endsWith('.markdown') ||
      lowerPath.endsWith('.mdx')) {
    return _markdownSupport;
  }
  if (lowerPath.endsWith('.graphql') || lowerPath.endsWith('.gql')) {
    return _graphqlSupport;
  }
  if (lowerPath.endsWith('.html') ||
      lowerPath.endsWith('.htm') ||
      lowerPath.endsWith('.xml') ||
      lowerPath.endsWith('.svg') ||
      lowerPath.endsWith('.vue')) {
    return CodeLanguageSupport(mode: xml, highlightLanguage: 'xml');
  }
  if (lowerPath.endsWith('.yml') || lowerPath.endsWith('.yaml')) {
    return _yamlSupport;
  }
  if (lowerPath.endsWith('.py')) {
    return CodeLanguageSupport(mode: python, highlightLanguage: 'python');
  }
  if (lowerPath.endsWith('.rs')) {
    return CodeLanguageSupport(mode: rust, highlightLanguage: 'rust');
  }
  if (lowerPath.endsWith('.sql')) {
    return CodeLanguageSupport(mode: sql, highlightLanguage: 'sql');
  }
  if (lowerPath.endsWith('.sh') ||
      lowerPath.endsWith('.bash') ||
      lowerPath.endsWith('.zsh')) {
    return _bashSupport;
  }
  if (lowerPath.endsWith('.php')) {
    return _phpSupport;
  }
  if (lowerPath.endsWith('.diff') || lowerPath.endsWith('.patch')) {
    return _diffSupport;
  }
  if (lowerPath.endsWith('.txt') || lowerPath.endsWith('.text')) {
    return _plaintextSupport;
  }

  return null;
}

Mode? languageModeForPath(String? path) =>
    codeLanguageSupportForPath(path)?.mode;

String? highlightLanguageForPath(String? path) =>
    codeLanguageSupportForPath(path)?.highlightLanguage;

String languageLabelForPath(String? path) {
  final support = codeLanguageSupportForPath(path);
  final name = support?.highlightLanguage;
  if (name == null || name.isEmpty) return 'Plain Text';
  return switch (name) {
    'cpp' => 'C++',
    'javascript' => 'JavaScript',
    'typescript' => 'TypeScript',
    'graphql' => 'GraphQL',
    'markdown' => 'Markdown',
    'plaintext' => 'Plain Text',
    'dockerfile' => 'Dockerfile',
    'makefile' => 'Makefile',
    _ => name[0].toUpperCase() + name.substring(1),
  };
}
