import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _materialIconAssetDir = 'assets/file_icons/material';

class FileTypeVisual {
  final IconData icon;
  final Color? color;
  final String? assetPath;

  const FileTypeVisual({required this.icon, this.color, this.assetPath});
}

class FolderTypeVisual {
  final IconData icon;
  final Color? color;
  final String? assetPath;
  final String? expandedAssetPath;

  const FolderTypeVisual({
    required this.icon,
    this.color,
    this.assetPath,
    this.expandedAssetPath,
  });
}

class _MaterialIconSpec {
  final String assetName;

  const _MaterialIconSpec(this.assetName);

  String get assetPath => '$_materialIconAssetDir/$assetName.svg';
}

class _MaterialFolderIconSpec {
  final String closedAssetName;
  final String openAssetName;

  const _MaterialFolderIconSpec({
    required this.closedAssetName,
    required this.openAssetName,
  });

  String get closedAssetPath => '$_materialIconAssetDir/$closedAssetName.svg';
  String get openAssetPath => '$_materialIconAssetDir/$openAssetName.svg';
}

const Map<String, _MaterialIconSpec> _fileNameIcons =
    <String, _MaterialIconSpec>{
      '.env': _MaterialIconSpec('tune'),
      '.env.example': _MaterialIconSpec('tune'),
      '.env.sample': _MaterialIconSpec('tune'),
      '.env.local': _MaterialIconSpec('tune'),
      '.watchmanconfig': _MaterialIconSpec('watchman'),
      '.rspec': _MaterialIconSpec('rspec'),
      '.ruff.toml': _MaterialIconSpec('ruff'),
      'ruff.toml': _MaterialIconSpec('ruff'),
      'readme': _MaterialIconSpec('readme'),
      'readme.md': _MaterialIconSpec('readme'),
      'license': _MaterialIconSpec('license'),
      'license.md': _MaterialIconSpec('license'),
      'changelog': _MaterialIconSpec('changelog'),
      'changelog.md': _MaterialIconSpec('changelog'),
      'favicon.ico': _MaterialIconSpec('favicon'),
      '.eslintrc': _MaterialIconSpec('eslint'),
      '.eslintignore': _MaterialIconSpec('eslint'),
      '.eslintcache': _MaterialIconSpec('eslint'),
      '.prettierrc': _MaterialIconSpec('prettier'),
      '.prettierignore': _MaterialIconSpec('prettier'),
      '.rubocop.yml': _MaterialIconSpec('rubocop'),
      '.rubocop-todo.yml': _MaterialIconSpec('rubocop'),
      '.rubocop_todo.yml': _MaterialIconSpec('rubocop'),
      '.commitlint.yml': _MaterialIconSpec('commitlint'),
      '.commitlint.yaml': _MaterialIconSpec('commitlint'),
      '.firebaserc': _MaterialIconSpec('firebase'),
      'firebase.json': _MaterialIconSpec('firebase'),
      'firestore.rules': _MaterialIconSpec('firebase'),
      'firestore.indexes.json': _MaterialIconSpec('firebase'),
      'package.json': _MaterialIconSpec('npm'),
      'package-lock.json': _MaterialIconSpec('npm'),
      '.npmrc': _MaterialIconSpec('npm'),
      '.npmignore': _MaterialIconSpec('npm'),
      'yarn.lock': _MaterialIconSpec('yarn'),
      'pnpm-lock.yaml': _MaterialIconSpec('pnpm'),
      'pnpm-workspace.yaml': _MaterialIconSpec('pnpm'),
      'bun.lock': _MaterialIconSpec('bun'),
      'bun.lockb': _MaterialIconSpec('bun'),
      'bunfig.toml': _MaterialIconSpec('bun'),
      'pubspec.yaml': _MaterialIconSpec('dart'),
      'pubspec.lock': _MaterialIconSpec('lock'),
      'tsconfig.json': _MaterialIconSpec('tsconfig'),
      'jsconfig.json': _MaterialIconSpec('tsconfig'),
      'androidmanifest.xml': _MaterialIconSpec('android'),
      'cargo.toml': _MaterialIconSpec('rust'),
      'cargo.lock': _MaterialIconSpec('lock'),
      'go.mod': _MaterialIconSpec('go-mod'),
      'go.sum': _MaterialIconSpec('go-mod'),
      'go.work': _MaterialIconSpec('go-mod'),
      'requirements.txt': _MaterialIconSpec('python'),
      'pyproject.toml': _MaterialIconSpec('python'),
      'poetry.lock': _MaterialIconSpec('poetry'),
      'uv.toml': _MaterialIconSpec('uv'),
      'uv.lock': _MaterialIconSpec('uv'),
      'gemfile': _MaterialIconSpec('gemfile'),
      'podfile': _MaterialIconSpec('ruby'),
      'podfile.lock': _MaterialIconSpec('lock'),
      'dockerfile': _MaterialIconSpec('docker'),
      'docker-compose.yml': _MaterialIconSpec('docker'),
      'docker-compose.yaml': _MaterialIconSpec('docker'),
      'compose.yml': _MaterialIconSpec('docker'),
      'compose.yaml': _MaterialIconSpec('docker'),
      'nginx.conf': _MaterialIconSpec('nginx'),
      '.graphqlconfig': _MaterialIconSpec('graphql'),
      'openapi.json': _MaterialIconSpec('openapi'),
      'openapi.yml': _MaterialIconSpec('openapi'),
      'openapi.yaml': _MaterialIconSpec('openapi'),
      'swagger.json': _MaterialIconSpec('swagger'),
      'swagger.yml': _MaterialIconSpec('swagger'),
      'swagger.yaml': _MaterialIconSpec('swagger'),
      'taskfile.yml': _MaterialIconSpec('taskfile'),
      'taskfile.yaml': _MaterialIconSpec('taskfile'),
      'cmakelists.txt': _MaterialIconSpec('cmake'),
      'justfile': _MaterialIconSpec('just'),
      '.justfile': _MaterialIconSpec('just'),
      'semgrep.yml': _MaterialIconSpec('semgrep'),
      '.semgrepignore': _MaterialIconSpec('semgrep'),
      '.mailmap': _MaterialIconSpec('email'),
      'biome.json': _MaterialIconSpec('biome'),
      'biome.jsonc': _MaterialIconSpec('biome'),
      '.biome.json': _MaterialIconSpec('biome'),
      '.biome.jsonc': _MaterialIconSpec('biome'),
      'lerna.json': _MaterialIconSpec('lerna'),
      'deno.json': _MaterialIconSpec('deno'),
      'deno.jsonc': _MaterialIconSpec('deno'),
      'deno.lock': _MaterialIconSpec('deno'),
      'turbo.json': _MaterialIconSpec('turborepo'),
      'turbo.jsonc': _MaterialIconSpec('turborepo'),
      '.gitlab-ci.yml': _MaterialIconSpec('gitlab'),
      'jenkinsfile': _MaterialIconSpec('jenkins'),
      '.helmignore': _MaterialIconSpec('helm'),
      'caddyfile': _MaterialIconSpec('caddy'),
      'pom.xml': _MaterialIconSpec('maven'),
      'drizzle.config.json': _MaterialIconSpec('drizzle'),
      'dependabot.yml': _MaterialIconSpec('dependabot'),
      'dependabot.yaml': _MaterialIconSpec('dependabot'),
      'circle.yml': _MaterialIconSpec('circleci'),
      '.drone.yml': _MaterialIconSpec('drone'),
      'buildkite.yml': _MaterialIconSpec('buildkite'),
      'buildkite.yaml': _MaterialIconSpec('buildkite'),
      '.appveyor.yml': _MaterialIconSpec('appveyor'),
      'appveyor.yml': _MaterialIconSpec('appveyor'),
      'azure-pipelines.yml': _MaterialIconSpec('azure-pipelines'),
      'azure-pipelines.yaml': _MaterialIconSpec('azure-pipelines'),
      'azure-pipelines-main.yml': _MaterialIconSpec('azure-pipelines'),
      'azure-pipelines-main.yaml': _MaterialIconSpec('azure-pipelines'),
      'netlify.toml': _MaterialIconSpec('netlify'),
      'netlify.yml': _MaterialIconSpec('netlify'),
      'netlify.yaml': _MaterialIconSpec('netlify'),
      'netlify.json': _MaterialIconSpec('netlify'),
      'vercel.json': _MaterialIconSpec('vercel'),
      '.vercelignore': _MaterialIconSpec('vercel'),
      'concourse.yml': _MaterialIconSpec('concourse'),
      'garden.yml': _MaterialIconSpec('garden'),
      'garden.yaml': _MaterialIconSpec('garden'),
      'project.garden.yml': _MaterialIconSpec('garden'),
      'project.garden.yaml': _MaterialIconSpec('garden'),
      '.gardenignore': _MaterialIconSpec('garden'),
      'steadybit.yml': _MaterialIconSpec('steadybit'),
      'steadybit.yaml': _MaterialIconSpec('steadybit'),
      '.steadybit.yml': _MaterialIconSpec('steadybit'),
      '.steadybit.yaml': _MaterialIconSpec('steadybit'),
      'werf.yml': _MaterialIconSpec('werf'),
      'werf.yaml': _MaterialIconSpec('werf'),
      'werf-giterminism.yml': _MaterialIconSpec('werf'),
      'werf-giterminism.yaml': _MaterialIconSpec('werf'),
      'werf-includes.yml': _MaterialIconSpec('werf'),
      'werf-includes.yaml': _MaterialIconSpec('werf'),
      'werf-includes.lock': _MaterialIconSpec('werf'),
      'renovate.json': _MaterialIconSpec('renovate'),
      'renovate.json5': _MaterialIconSpec('renovate'),
      '.renovaterc': _MaterialIconSpec('renovate'),
      '.renovaterc.json': _MaterialIconSpec('renovate'),
      '.release-it.json': _MaterialIconSpec('semantic-release'),
      '.release-it.yml': _MaterialIconSpec('semantic-release'),
      '.release-it.yaml': _MaterialIconSpec('semantic-release'),
      '.release-it.toml': _MaterialIconSpec('semantic-release'),
      'chromatic.config.json': _MaterialIconSpec('chromatic'),
      '.happo.js': _MaterialIconSpec('happo'),
      '.happo.mjs': _MaterialIconSpec('happo'),
      '.happo.cjs': _MaterialIconSpec('happo'),
      '.sentryclirc': _MaterialIconSpec('sentry'),
      'sonar-project.properties': _MaterialIconSpec('sonarcloud'),
      '.sonarcloud.properties': _MaterialIconSpec('sonarcloud'),
      'sonarcloud.yaml': _MaterialIconSpec('sonarcloud'),
      'phpstan.neon': _MaterialIconSpec('phpstan'),
      'phpstan.neon.dist': _MaterialIconSpec('phpstan'),
      'phpstan.dist.neon': _MaterialIconSpec('phpstan'),
      'mermaid': _MaterialIconSpec('mermaid'),
      '.codeclimate.yml': _MaterialIconSpec('code-climate'),
    };

const List<MapEntry<String, _MaterialIconSpec>> _fileStemIcons =
    <MapEntry<String, _MaterialIconSpec>>[
      MapEntry('.env.', _MaterialIconSpec('tune')),
      MapEntry('.eslintrc.', _MaterialIconSpec('eslint')),
      MapEntry('.prettierrc.', _MaterialIconSpec('prettier')),
      MapEntry('.commitlintrc.', _MaterialIconSpec('commitlint')),
      MapEntry('.czrc.', _MaterialIconSpec('commitizen')),
      MapEntry('playwright.config.', _MaterialIconSpec('playwright')),
      MapEntry('playwright-ct.config.', _MaterialIconSpec('playwright')),
      MapEntry('astro.config.', _MaterialIconSpec('astro-config')),
      MapEntry('next.config.', _MaterialIconSpec('next')),
      MapEntry('nuxt.config.', _MaterialIconSpec('nuxt')),
      MapEntry('vite.config.', _MaterialIconSpec('vite')),
      MapEntry('vitest.config.', _MaterialIconSpec('vitest')),
      MapEntry('vitest.workspace.', _MaterialIconSpec('vitest')),
      MapEntry('vitest.unit.config.', _MaterialIconSpec('vitest')),
      MapEntry('vitest.e2e.config.', _MaterialIconSpec('vitest')),
      MapEntry('jest.config.', _MaterialIconSpec('jest')),
      MapEntry('jest.setup.', _MaterialIconSpec('jest')),
      MapEntry('cypress.config.', _MaterialIconSpec('cypress')),
      MapEntry('tailwind.config.', _MaterialIconSpec('tailwindcss')),
      MapEntry('vue.config.', _MaterialIconSpec('vue-config')),
      MapEntry('svelte.config.', _MaterialIconSpec('svelte')),
      MapEntry('drizzle.config.', _MaterialIconSpec('database')),
      MapEntry('webpack.config.', _MaterialIconSpec('webpack')),
      MapEntry('rollup.config.', _MaterialIconSpec('rollup')),
      MapEntry('babel.config.', _MaterialIconSpec('babel')),
      MapEntry('hardhat.config.', _MaterialIconSpec('hardhat')),
      MapEntry('plopfile.', _MaterialIconSpec('plop')),
      MapEntry('craco.config.', _MaterialIconSpec('craco')),
      MapEntry('parcelrc.', _MaterialIconSpec('parcel')),
      MapEntry('wrangler.', _MaterialIconSpec('wrangler')),
      MapEntry('tauri.conf.', _MaterialIconSpec('tauri')),
      MapEntry('tauri.config.', _MaterialIconSpec('tauri')),
      MapEntry('serverless.', _MaterialIconSpec('serverless')),
      MapEntry('postcss.config.', _MaterialIconSpec('postcss')),
      MapEntry('windi.config.', _MaterialIconSpec('windicss')),
      MapEntry('uno.config.', _MaterialIconSpec('unocss')),
      MapEntry('unocss.config.', _MaterialIconSpec('unocss')),
      MapEntry('sentry.client.config.', _MaterialIconSpec('sentry')),
      MapEntry('sentry.server.config.', _MaterialIconSpec('sentry')),
      MapEntry('sentry.edge.config.', _MaterialIconSpec('sentry')),
      MapEntry('syncpack.', _MaterialIconSpec('syncpack')),
      MapEntry('terraform.', _MaterialIconSpec('terraform')),
      MapEntry('tsconfig.', _MaterialIconSpec('tsconfig')),
      MapEntry('supabase.', _MaterialIconSpec('supabase')),
      MapEntry('esbuild.config.', _MaterialIconSpec('esbuild')),
    ];

const List<MapEntry<String, _MaterialIconSpec>> _fileSuffixIcons =
    <MapEntry<String, _MaterialIconSpec>>[
      MapEntry('markdown', _MaterialIconSpec('markdown')),
      MapEntry('dart', _MaterialIconSpec('dart')),
      MapEntry('tsx', _MaterialIconSpec('react_ts')),
      MapEntry('ts', _MaterialIconSpec('typescript')),
      MapEntry('jsx', _MaterialIconSpec('react')),
      MapEntry('js', _MaterialIconSpec('javascript')),
      MapEntry('json', _MaterialIconSpec('json')),
      MapEntry('jsonc', _MaterialIconSpec('json')),
      MapEntry('json5', _MaterialIconSpec('json')),
      MapEntry('jsonl', _MaterialIconSpec('json')),
      MapEntry('yaml', _MaterialIconSpec('yaml')),
      MapEntry('yml', _MaterialIconSpec('yaml')),
      MapEntry('toml', _MaterialIconSpec('toml')),
      MapEntry('hjson', _MaterialIconSpec('hjson')),
      MapEntry('txt', _MaterialIconSpec('document')),
      MapEntry('xml', _MaterialIconSpec('xml')),
      MapEntry('html', _MaterialIconSpec('html')),
      MapEntry('htm', _MaterialIconSpec('html')),
      MapEntry('vue', _MaterialIconSpec('vue-config')),
      MapEntry('svelte', _MaterialIconSpec('svelte')),
      MapEntry('astro', _MaterialIconSpec('astro-config')),
      MapEntry('mmd', _MaterialIconSpec('mermaid')),
      MapEntry('mermaid', _MaterialIconSpec('mermaid')),
      MapEntry('scss', _MaterialIconSpec('sass')),
      MapEntry('sass', _MaterialIconSpec('sass')),
      MapEntry('css', _MaterialIconSpec('css')),
      MapEntry('less', _MaterialIconSpec('less')),
      MapEntry('md', _MaterialIconSpec('markdown')),
      MapEntry('rst', _MaterialIconSpec('markdown')),
      MapEntry('prompt.md', _MaterialIconSpec('prompt')),
      MapEntry('csv', _MaterialIconSpec('table')),
      MapEntry('tsv', _MaterialIconSpec('table')),
      MapEntry('psv', _MaterialIconSpec('table')),
      MapEntry('xls', _MaterialIconSpec('table')),
      MapEntry('xlsx', _MaterialIconSpec('table')),
      MapEntry('xlsm', _MaterialIconSpec('table')),
      MapEntry('ods', _MaterialIconSpec('table')),
      MapEntry('doc', _MaterialIconSpec('word')),
      MapEntry('docx', _MaterialIconSpec('word')),
      MapEntry('rtf', _MaterialIconSpec('word')),
      MapEntry('odt', _MaterialIconSpec('word')),
      MapEntry('ppt', _MaterialIconSpec('powerpoint')),
      MapEntry('pptx', _MaterialIconSpec('powerpoint')),
      MapEntry('pptm', _MaterialIconSpec('powerpoint')),
      MapEntry('potx', _MaterialIconSpec('powerpoint')),
      MapEntry('potm', _MaterialIconSpec('powerpoint')),
      MapEntry('pps', _MaterialIconSpec('powerpoint')),
      MapEntry('ppsx', _MaterialIconSpec('powerpoint')),
      MapEntry('ppsm', _MaterialIconSpec('powerpoint')),
      MapEntry('odp', _MaterialIconSpec('powerpoint')),
      MapEntry('sql', _MaterialIconSpec('database')),
      MapEntry('neon', _MaterialIconSpec('phpstan')),
      MapEntry('prisma', _MaterialIconSpec('prisma')),
      MapEntry('graphql', _MaterialIconSpec('graphql')),
      MapEntry('gql', _MaterialIconSpec('graphql')),
      MapEntry('gradle', _MaterialIconSpec('gradle')),
      MapEntry('phpunit.xml', _MaterialIconSpec('phpunit')),
      MapEntry('phpunit.xml.dist', _MaterialIconSpec('phpunit')),
      MapEntry('tf', _MaterialIconSpec('terraform')),
      MapEntry('tfvars', _MaterialIconSpec('terraform')),
      MapEntry('hcl', _MaterialIconSpec('terraform')),
      MapEntry('bash', _MaterialIconSpec('bashly')),
      MapEntry('zsh', _MaterialIconSpec('bashly')),
      MapEntry('fish', _MaterialIconSpec('bashly')),
      MapEntry('sh', _MaterialIconSpec('bashly')),
      MapEntry('ps1', _MaterialIconSpec('powershell')),
      MapEntry('env', _MaterialIconSpec('tune')),
      MapEntry('py', _MaterialIconSpec('python')),
      MapEntry('rs', _MaterialIconSpec('rust')),
      MapEntry('go', _MaterialIconSpec('go-mod')),
      MapEntry('g.dart', _MaterialIconSpec('dart_generated')),
      MapEntry('freezed.dart', _MaterialIconSpec('dart_generated')),
      MapEntry('d.ts', _MaterialIconSpec('typescript-def')),
      MapEntry('java', _MaterialIconSpec('java')),
      MapEntry('kt', _MaterialIconSpec('kotlin')),
      MapEntry('kts', _MaterialIconSpec('kotlin')),
      MapEntry('swift', _MaterialIconSpec('swift')),
      MapEntry('php', _MaterialIconSpec('php')),
      MapEntry('rb', _MaterialIconSpec('ruby')),
      MapEntry('c', _MaterialIconSpec('c')),
      MapEntry('h', _MaterialIconSpec('h')),
      MapEntry('hpp', _MaterialIconSpec('h')),
      MapEntry('cc', _MaterialIconSpec('cpp')),
      MapEntry('cpp', _MaterialIconSpec('cpp')),
      MapEntry('cxx', _MaterialIconSpec('cpp')),
      MapEntry('cmake', _MaterialIconSpec('cmake')),
      MapEntry('cer', _MaterialIconSpec('certificate')),
      MapEntry('cert', _MaterialIconSpec('certificate')),
      MapEntry('crt', _MaterialIconSpec('certificate')),
      MapEntry('ai', _MaterialIconSpec('adobe-illustrator')),
      MapEntry('ait', _MaterialIconSpec('adobe-illustrator')),
      MapEntry('psd', _MaterialIconSpec('adobe-photoshop')),
      MapEntry('psb', _MaterialIconSpec('adobe-photoshop')),
      MapEntry('psdt', _MaterialIconSpec('adobe-photoshop')),
      MapEntry('fig', _MaterialIconSpec('figma')),
      MapEntry('drawio', _MaterialIconSpec('drawio')),
      MapEntry('dio', _MaterialIconSpec('drawio')),
      MapEntry('blend', _MaterialIconSpec('blender')),
      MapEntry('blend1', _MaterialIconSpec('blender')),
      MapEntry('blend2', _MaterialIconSpec('blender')),
      MapEntry('pal', _MaterialIconSpec('palette')),
      MapEntry('gpl', _MaterialIconSpec('palette')),
      MapEntry('act', _MaterialIconSpec('palette')),
      MapEntry('zip', _MaterialIconSpec('zip')),
      MapEntry('tar', _MaterialIconSpec('zip')),
      MapEntry('gz', _MaterialIconSpec('zip')),
      MapEntry('xz', _MaterialIconSpec('zip')),
      MapEntry('lz', _MaterialIconSpec('zip')),
      MapEntry('7z', _MaterialIconSpec('zip')),
      MapEntry('rar', _MaterialIconSpec('zip')),
      MapEntry('bz2', _MaterialIconSpec('zip')),
      MapEntry('tgz', _MaterialIconSpec('zip')),
      MapEntry('eml', _MaterialIconSpec('email')),
      MapEntry('emlx', _MaterialIconSpec('email')),
      MapEntry('ics', _MaterialIconSpec('email')),
      MapEntry('mbox', _MaterialIconSpec('email')),
      MapEntry('msg', _MaterialIconSpec('email')),
      MapEntry('ost', _MaterialIconSpec('email')),
      MapEntry('pst', _MaterialIconSpec('email')),
      MapEntry('epub', _MaterialIconSpec('epub')),
      MapEntry('woff', _MaterialIconSpec('font')),
      MapEntry('woff2', _MaterialIconSpec('font')),
      MapEntry('ttf', _MaterialIconSpec('font')),
      MapEntry('otf', _MaterialIconSpec('font')),
      MapEntry('ttc', _MaterialIconSpec('font')),
      MapEntry('eot', _MaterialIconSpec('font')),
      MapEntry('mp3', _MaterialIconSpec('audio')),
      MapEntry('wav', _MaterialIconSpec('audio')),
      MapEntry('m4a', _MaterialIconSpec('audio')),
      MapEntry('flac', _MaterialIconSpec('audio')),
      MapEntry('aac', _MaterialIconSpec('audio')),
      MapEntry('ogg', _MaterialIconSpec('audio')),
      MapEntry('opus', _MaterialIconSpec('audio')),
      MapEntry('weba', _MaterialIconSpec('audio')),
      MapEntry('mp4', _MaterialIconSpec('video')),
      MapEntry('m4v', _MaterialIconSpec('video')),
      MapEntry('mov', _MaterialIconSpec('video')),
      MapEntry('avi', _MaterialIconSpec('video')),
      MapEntry('mkv', _MaterialIconSpec('video')),
      MapEntry('webm', _MaterialIconSpec('video')),
      MapEntry('mpeg', _MaterialIconSpec('video')),
      MapEntry('mpg', _MaterialIconSpec('video')),
      MapEntry('wmv', _MaterialIconSpec('video')),
      MapEntry('png', _MaterialIconSpec('image')),
      MapEntry('jpg', _MaterialIconSpec('image')),
      MapEntry('jpeg', _MaterialIconSpec('image')),
      MapEntry('gif', _MaterialIconSpec('image')),
      MapEntry('webp', _MaterialIconSpec('image')),
      MapEntry('bmp', _MaterialIconSpec('image')),
      MapEntry('ico', _MaterialIconSpec('image')),
      MapEntry('tif', _MaterialIconSpec('image')),
      MapEntry('tiff', _MaterialIconSpec('image')),
      MapEntry('avif', _MaterialIconSpec('image')),
      MapEntry('heic', _MaterialIconSpec('image')),
      MapEntry('heif', _MaterialIconSpec('image')),
      MapEntry('apk', _MaterialIconSpec('android')),
      MapEntry('dex', _MaterialIconSpec('android')),
      MapEntry('smali', _MaterialIconSpec('android')),
      MapEntry('svg', _MaterialIconSpec('svg')),
      MapEntry('pdf', _MaterialIconSpec('pdf')),
      MapEntry('proto', _MaterialIconSpec('proto')),
      MapEntry('drone.yml', _MaterialIconSpec('drone')),
      MapEntry('garden.yml', _MaterialIconSpec('garden')),
      MapEntry('garden.yaml', _MaterialIconSpec('garden')),
    ];

const Map<String, _MaterialFolderIconSpec> _folderPathIcons =
    <String, _MaterialFolderIconSpec>{
      '.github/workflows': _MaterialFolderIconSpec(
        closedAssetName: 'folder-gh-workflows',
        openAssetName: 'folder-gh-workflows-open',
      ),
    };

const Map<String, _MaterialFolderIconSpec> _folderNameIcons =
    <String, _MaterialFolderIconSpec>{
      'src': _MaterialFolderIconSpec(
        closedAssetName: 'folder-src',
        openAssetName: 'folder-src-open',
      ),
      'lib': _MaterialFolderIconSpec(
        closedAssetName: 'folder-lib',
        openAssetName: 'folder-lib-open',
      ),
      'assets': _MaterialFolderIconSpec(
        closedAssetName: 'folder-resource',
        openAssetName: 'folder-resource-open',
      ),
      'docs': _MaterialFolderIconSpec(
        closedAssetName: 'folder-docs',
        openAssetName: 'folder-docs-open',
      ),
      'test': _MaterialFolderIconSpec(
        closedAssetName: 'folder-test',
        openAssetName: 'folder-test-open',
      ),
      'tests': _MaterialFolderIconSpec(
        closedAssetName: 'folder-test',
        openAssetName: 'folder-test-open',
      ),
      'scripts': _MaterialFolderIconSpec(
        closedAssetName: 'folder-scripts',
        openAssetName: 'folder-scripts-open',
      ),
      '.github': _MaterialFolderIconSpec(
        closedAssetName: 'folder-github',
        openAssetName: 'folder-github-open',
      ),
      '.vscode': _MaterialFolderIconSpec(
        closedAssetName: 'folder-vscode',
        openAssetName: 'folder-vscode-open',
      ),
      'node_modules': _MaterialFolderIconSpec(
        closedAssetName: 'folder-node',
        openAssetName: 'folder-node-open',
      ),
      'android': _MaterialFolderIconSpec(
        closedAssetName: 'folder-android',
        openAssetName: 'folder-android-open',
      ),
      'ios': _MaterialFolderIconSpec(
        closedAssetName: 'folder-ios',
        openAssetName: 'folder-ios-open',
      ),
      'macos': _MaterialFolderIconSpec(
        closedAssetName: 'folder-macos',
        openAssetName: 'folder-macos-open',
      ),
      'web': _MaterialFolderIconSpec(
        closedAssetName: 'folder-public',
        openAssetName: 'folder-public-open',
      ),
      'widgets': _MaterialFolderIconSpec(
        closedAssetName: 'folder-components',
        openAssetName: 'folder-components-open',
      ),
      'components': _MaterialFolderIconSpec(
        closedAssetName: 'folder-components',
        openAssetName: 'folder-components-open',
      ),
      'screens': _MaterialFolderIconSpec(
        closedAssetName: 'folder-views',
        openAssetName: 'folder-views-open',
      ),
      'models': _MaterialFolderIconSpec(
        closedAssetName: 'folder-class',
        openAssetName: 'folder-class-open',
      ),
      'services': _MaterialFolderIconSpec(
        closedAssetName: 'folder-server',
        openAssetName: 'folder-server-open',
      ),
      'providers': _MaterialFolderIconSpec(
        closedAssetName: 'folder-context',
        openAssetName: 'folder-context-open',
      ),
      'utils': _MaterialFolderIconSpec(
        closedAssetName: 'folder-utils',
        openAssetName: 'folder-utils-open',
      ),
      'hooks': _MaterialFolderIconSpec(
        closedAssetName: 'folder-hook',
        openAssetName: 'folder-hook-open',
      ),
      'styles': _MaterialFolderIconSpec(
        closedAssetName: 'folder-css',
        openAssetName: 'folder-css-open',
      ),
      'images': _MaterialFolderIconSpec(
        closedAssetName: 'folder-images',
        openAssetName: 'folder-images-open',
      ),
      'fonts': _MaterialFolderIconSpec(
        closedAssetName: 'folder-font',
        openAssetName: 'folder-font-open',
      ),
      'database': _MaterialFolderIconSpec(
        closedAssetName: 'folder-database',
        openAssetName: 'folder-database-open',
      ),
      'migrations': _MaterialFolderIconSpec(
        closedAssetName: 'folder-migrations',
        openAssetName: 'folder-migrations-open',
      ),
      'api': _MaterialFolderIconSpec(
        closedAssetName: 'folder-api',
        openAssetName: 'folder-api-open',
      ),
      'public': _MaterialFolderIconSpec(
        closedAssetName: 'folder-public',
        openAssetName: 'folder-public-open',
      ),
      'build': _MaterialFolderIconSpec(
        closedAssetName: 'folder-dist',
        openAssetName: 'folder-dist-open',
      ),
      'dist': _MaterialFolderIconSpec(
        closedAssetName: 'folder-dist',
        openAssetName: 'folder-dist-open',
      ),
      'l10n': _MaterialFolderIconSpec(
        closedAssetName: 'folder-i18n',
        openAssetName: 'folder-i18n-open',
      ),
      'locales': _MaterialFolderIconSpec(
        closedAssetName: 'folder-i18n',
        openAssetName: 'folder-i18n-open',
      ),
      'graphql': _MaterialFolderIconSpec(
        closedAssetName: 'folder-graphql',
        openAssetName: 'folder-graphql-open',
      ),
      'kubernetes': _MaterialFolderIconSpec(
        closedAssetName: 'folder-kubernetes',
        openAssetName: 'folder-kubernetes-open',
      ),
      'ci': _MaterialFolderIconSpec(
        closedAssetName: 'folder-ci',
        openAssetName: 'folder-ci-open',
      ),
      'circleci': _MaterialFolderIconSpec(
        closedAssetName: 'folder-circleci',
        openAssetName: 'folder-circleci-open',
      ),
      'supabase': _MaterialFolderIconSpec(
        closedAssetName: 'folder-supabase',
        openAssetName: 'folder-supabase-open',
      ),
      'prisma': _MaterialFolderIconSpec(
        closedAssetName: 'folder-prisma',
        openAssetName: 'folder-prisma-open',
      ),
      'terraform': _MaterialFolderIconSpec(
        closedAssetName: 'folder-terraform',
        openAssetName: 'folder-terraform-open',
      ),
      'firebase': _MaterialFolderIconSpec(
        closedAssetName: 'folder-firebase',
        openAssetName: 'folder-firebase-open',
      ),
      'svelte': _MaterialFolderIconSpec(
        closedAssetName: 'folder-svelte',
        openAssetName: 'folder-svelte-open',
      ),
      'next': _MaterialFolderIconSpec(
        closedAssetName: 'folder-next',
        openAssetName: 'folder-next-open',
      ),
      'storybook': _MaterialFolderIconSpec(
        closedAssetName: 'folder-storybook',
        openAssetName: 'folder-storybook-open',
      ),
      'flutter': _MaterialFolderIconSpec(
        closedAssetName: 'folder-flutter',
        openAssetName: 'folder-flutter-open',
      ),
      'env': _MaterialFolderIconSpec(
        closedAssetName: 'folder-environment',
        openAssetName: 'folder-environment-open',
      ),
      'packages': _MaterialFolderIconSpec(
        closedAssetName: 'folder-packages',
        openAssetName: 'folder-packages-open',
      ),
      'examples': _MaterialFolderIconSpec(
        closedAssetName: 'folder-examples',
        openAssetName: 'folder-examples-open',
      ),
      'coverage': _MaterialFolderIconSpec(
        closedAssetName: 'folder-coverage',
        openAssetName: 'folder-coverage-open',
      ),
      'themes': _MaterialFolderIconSpec(
        closedAssetName: 'folder-theme',
        openAssetName: 'folder-theme-open',
      ),
      'plugins': _MaterialFolderIconSpec(
        closedAssetName: 'folder-plugin',
        openAssetName: 'folder-plugin-open',
      ),
      'store': _MaterialFolderIconSpec(
        closedAssetName: 'folder-store',
        openAssetName: 'folder-store-open',
      ),
      'policies': _MaterialFolderIconSpec(
        closedAssetName: 'folder-policy',
        openAssetName: 'folder-policy-open',
      ),
      'templates': _MaterialFolderIconSpec(
        closedAssetName: 'folder-template',
        openAssetName: 'folder-template-open',
      ),
      'nuxt': _MaterialFolderIconSpec(
        closedAssetName: 'folder-nuxt',
        openAssetName: 'folder-nuxt-open',
      ),
      'vue': _MaterialFolderIconSpec(
        closedAssetName: 'folder-vue',
        openAssetName: 'folder-vue-open',
      ),
      'serverless': _MaterialFolderIconSpec(
        closedAssetName: 'folder-serverless',
        openAssetName: 'folder-serverless-open',
      ),
      'netlify': _MaterialFolderIconSpec(
        closedAssetName: 'folder-netlify',
        openAssetName: 'folder-netlify-open',
      ),
      'vercel': _MaterialFolderIconSpec(
        closedAssetName: 'folder-vercel',
        openAssetName: 'folder-vercel-open',
      ),
      'docker': _MaterialFolderIconSpec(
        closedAssetName: 'folder-docker',
        openAssetName: 'folder-docker-open',
      ),
      'helm': _MaterialFolderIconSpec(
        closedAssetName: 'folder-helm',
        openAssetName: 'folder-helm-open',
      ),
      'gradle': _MaterialFolderIconSpec(
        closedAssetName: 'folder-gradle',
        openAssetName: 'folder-gradle-open',
      ),
      'go': _MaterialFolderIconSpec(
        closedAssetName: 'folder-go',
        openAssetName: 'folder-go-open',
      ),
      'nginx': _MaterialFolderIconSpec(
        closedAssetName: 'folder-nginx',
        openAssetName: 'folder-nginx-open',
      ),
      'metro': _MaterialFolderIconSpec(
        closedAssetName: 'folder-metro',
        openAssetName: 'folder-metro-open',
      ),
      '.yarn': _MaterialFolderIconSpec(
        closedAssetName: 'folder-yarn',
        openAssetName: 'folder-yarn-open',
      ),
      'home': _MaterialFolderIconSpec(
        closedAssetName: 'folder-home',
        openAssetName: 'folder-home-open',
      ),
      'debug': _MaterialFolderIconSpec(
        closedAssetName: 'folder-debug',
        openAssetName: 'folder-debug-open',
      ),
      'secure': _MaterialFolderIconSpec(
        closedAssetName: 'folder-secure',
        openAssetName: 'folder-secure-open',
      ),
      'contracts': _MaterialFolderIconSpec(
        closedAssetName: 'folder-contract',
        openAssetName: 'folder-contract-open',
      ),
      'taskfile': _MaterialFolderIconSpec(
        closedAssetName: 'folder-taskfile',
        openAssetName: 'folder-taskfile-open',
      ),
      'functions': _MaterialFolderIconSpec(
        closedAssetName: 'folder-cloud-functions',
        openAssetName: 'folder-cloud-functions-open',
      ),
      '.husky': _MaterialFolderIconSpec(
        closedAssetName: 'folder-husky',
        openAssetName: 'folder-husky-open',
      ),
      '.gitlab': _MaterialFolderIconSpec(
        closedAssetName: 'folder-gitlab',
        openAssetName: 'folder-gitlab-open',
      ),
      'review': _MaterialFolderIconSpec(
        closedAssetName: 'folder-review',
        openAssetName: 'folder-review-open',
      ),
      'repository': _MaterialFolderIconSpec(
        closedAssetName: 'folder-repository',
        openAssetName: 'folder-repository-open',
      ),
      'queue': _MaterialFolderIconSpec(
        closedAssetName: 'folder-queue',
        openAssetName: 'folder-queue-open',
      ),
      'jobs': _MaterialFolderIconSpec(
        closedAssetName: 'folder-job',
        openAssetName: 'folder-job-open',
      ),
      'containers': _MaterialFolderIconSpec(
        closedAssetName: 'folder-container',
        openAssetName: 'folder-container-open',
      ),
      'commands': _MaterialFolderIconSpec(
        closedAssetName: 'folder-command',
        openAssetName: 'folder-command-open',
      ),
      'batches': _MaterialFolderIconSpec(
        closedAssetName: 'folder-batch',
        openAssetName: 'folder-batch-open',
      ),
      'guards': _MaterialFolderIconSpec(
        closedAssetName: 'folder-guard',
        openAssetName: 'folder-guard-open',
      ),
      'keys': _MaterialFolderIconSpec(
        closedAssetName: 'folder-keys',
        openAssetName: 'folder-keys-open',
      ),
      'rules': _MaterialFolderIconSpec(
        closedAssetName: 'folder-rules',
        openAssetName: 'folder-rules-open',
      ),
    };

FileTypeVisual fileTypeVisual(ThemeData theme, String path) {
  final lower = path.toLowerCase().trim();
  final basename = _basename(lower);

  final exact = _fileNameIcons[basename];
  if (exact != null) {
    return FileTypeVisual(
      icon: Icons.insert_drive_file_outlined,
      color: theme.colorScheme.onSurfaceVariant,
      assetPath: exact.assetPath,
    );
  }

  for (final entry in _fileStemIcons) {
    if (_matchesFileStem(basename, entry.key)) {
      return FileTypeVisual(
        icon: Icons.insert_drive_file_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        assetPath: entry.value.assetPath,
      );
    }
  }

  for (final entry in _fileSuffixIcons) {
    if (_hasSuffix(basename, entry.key)) {
      return FileTypeVisual(
        icon: Icons.insert_drive_file_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        assetPath: entry.value.assetPath,
      );
    }
  }

  if (basename.endsWith('.lock')) {
    return FileTypeVisual(
      icon: Icons.lock_outline,
      color: theme.colorScheme.onSurfaceVariant,
      assetPath: const _MaterialIconSpec('lock').assetPath,
    );
  }

  return FileTypeVisual(
    icon: Icons.insert_drive_file_outlined,
    color: theme.colorScheme.onSurfaceVariant,
  );
}

FolderTypeVisual folderTypeVisual(ThemeData theme, String path) {
  final lower = path.toLowerCase().trim().replaceAll(RegExp(r'^/+|/+$'), '');
  final basename = _basename(lower);

  final byPath = _folderPathIcons[lower];
  if (byPath != null) {
    return FolderTypeVisual(
      icon: Icons.folder,
      color: theme.colorScheme.secondary,
      assetPath: byPath.closedAssetPath,
      expandedAssetPath: byPath.openAssetPath,
    );
  }

  final byName = _folderNameIcons[basename];
  if (byName != null) {
    return FolderTypeVisual(
      icon: Icons.folder,
      color: theme.colorScheme.secondary,
      assetPath: byName.closedAssetPath,
      expandedAssetPath: byName.openAssetPath,
    );
  }

  return const FolderTypeVisual(
    icon: Icons.folder,
    assetPath: 'assets/file_icons/material/folder-base.svg',
    expandedAssetPath: 'assets/file_icons/material/folder-base-open.svg',
  );
}

Widget buildFileTypeIcon(
  BuildContext context,
  String path, {
  double size = 18,
  Color? fallbackColor,
}) {
  final visual = fileTypeVisual(Theme.of(context), path);
  if (visual.assetPath != null) {
    return SvgPicture.asset(
      visual.assetPath!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          '[file_type_visual] Failed to load file icon asset "${visual.assetPath}": $error',
        );
        return Icon(
          visual.icon,
          size: size,
          color: fallbackColor ?? visual.color,
        );
      },
    );
  }

  return Icon(visual.icon, size: size, color: fallbackColor ?? visual.color);
}

Widget buildFolderTypeIcon(
  BuildContext context,
  String path, {
  required bool expanded,
  double size = 18,
  Color? fallbackColor,
}) {
  final visual = folderTypeVisual(Theme.of(context), path);
  final assetPath = expanded
      ? (visual.expandedAssetPath ?? visual.assetPath)
      : visual.assetPath;

  if (assetPath != null) {
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          '[file_type_visual] Failed to load folder icon asset "$assetPath": $error',
        );
        return Icon(
          expanded ? Icons.folder_open : visual.icon,
          size: size,
          color: fallbackColor ?? visual.color,
        );
      },
    );
  }

  return Icon(
    expanded ? Icons.folder_open : visual.icon,
    size: size,
    color: fallbackColor ?? visual.color,
  );
}

String _basename(String path) {
  final parts = path.split('/');
  return parts.isEmpty ? path : parts.last;
}

bool _hasSuffix(String basename, String suffix) {
  return basename == suffix || basename.endsWith('.$suffix');
}

bool _matchesFileStem(String basename, String stem) {
  return basename == stem || basename.startsWith(stem);
}
