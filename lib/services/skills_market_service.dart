import 'dart:convert';
import 'dart:io';

import '../models/prompt_item.dart';
import 'skills_market_credentials.dart';

class SkillsMarketService {
  SkillsMarketService({
    HttpClient? httpClient,
    String? apiKey,
    Future<SkillsMarketCredentials> Function()? loadCredentials,
  }) : _httpClient = httpClient ?? HttpClient(),
       _apiKey = apiKey?.trim(),
       _loadCredentials = loadCredentials ?? SkillsMarketCredentials.load;

  static const String _host = 'skills.sh';
  static const String _browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Safari/537.36';
  static const String _acceptLanguage = 'en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7';

  final HttpClient _httpClient;
  final String? _apiKey;
  final Future<SkillsMarketCredentials> Function() _loadCredentials;
  Future<SkillsMarketCredentials>? _credentialsFuture;

  Future<List<PromptItem>> fetchSkills({
    String query = '',
    int limit = 50,
    int offset = 0,
  }) async {
    final trimmedQuery = query.trim();
    final uri = trimmedQuery.isEmpty
        ? Uri.https(_host, '/api/v1/skills', {
            'limit': '$limit',
            'offset': '$offset',
          })
        : Uri.https(_host, '/api/v1/skills/search', {
            'q': trimmedQuery,
            'limit': '$limit',
            'offset': '$offset',
          });

    try {
      final decoded = await _getJson(uri);
      final entries = _extractList(decoded);

      return entries
          .whereType<Map<String, dynamic>>()
          .map(_skillFromJson)
          .whereType<PromptItem>()
          .toList();
    } on Object {
      final html = await _getText(Uri.https(_host, '/'));
      final skills = _skillsFromHtml(html);
      return _filterHtmlSkills(skills, trimmedQuery).take(limit).toList();
    }
  }

  Future<PromptItem> fetchSkillDetails(PromptItem item) async {
    final id = item.marketId ?? item.id.replaceFirst('market-', '');
    try {
      final decoded = await _getJson(Uri.https(_host, '/api/v1/skills/$id'));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'skills.sh returned an invalid skill detail',
        );
      }

      final detail = _extractDetail(decoded);
      final hydrated = _skillFromJson(detail) ?? item;
      final content = _readSkillContent(detail) ?? item.content;
      final files = _readSkillFiles(detail);

      return hydrated.copyWith(
        id: item.id,
        scope: item.scope,
        enabledAgents: item.enabledAgents,
        enabledProjectIds: item.enabledProjectIds,
        content: content,
        marketFiles: files,
      );
    } on Object {
      final path = _htmlDetailPath(item);
      final html = await _getText(Uri.https(_host, path));
      return _skillDetailsFromHtml(item, html);
    }
  }

  Future<Object?> _getJson(Uri uri) async {
    final request = await _httpClient.getUrl(uri);
    _setBrowserHeaders(request, accept: 'application/json, text/plain, */*');
    await _setAuthorizationHeader(request);

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        _readErrorMessage(body) ?? 'skills.sh returned ${response.statusCode}',
        uri: uri,
      );
    }

    return jsonDecode(body);
  }

  Future<String> _getText(Uri uri) async {
    final request = await _httpClient.getUrl(uri);
    _setBrowserHeaders(
      request,
      accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      includeNavigationHeaders: true,
    );

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'skills.sh returned ${response.statusCode}',
        uri: uri,
      );
    }

    return body;
  }

  void _setBrowserHeaders(
    HttpClientRequest request, {
    required String accept,
    bool includeNavigationHeaders = false,
  }) {
    request.headers.set(HttpHeaders.acceptHeader, accept);
    request.headers.set(HttpHeaders.userAgentHeader, _browserUserAgent);
    request.headers.set(HttpHeaders.acceptLanguageHeader, _acceptLanguage);
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    request.headers.set(HttpHeaders.pragmaHeader, 'no-cache');

    if (includeNavigationHeaders) {
      request.headers.set('Upgrade-Insecure-Requests', '1');
      request.headers.set('Sec-Fetch-Dest', 'document');
      request.headers.set('Sec-Fetch-Mode', 'navigate');
      request.headers.set('Sec-Fetch-Site', 'none');
      request.headers.set('Sec-Fetch-User', '?1');
    }
  }

  Future<void> _setAuthorizationHeader(HttpClientRequest request) async {
    final apiKey = await _resolveApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return;
    }

    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
  }

  Future<String?> _resolveApiKey() async {
    final injected = _apiKey;
    if (injected != null && injected.isNotEmpty) {
      return injected;
    }

    final credentialsFuture = _credentialsFuture ??= _loadCredentials();
    final credentials = await credentialsFuture;
    final loaded = credentials.apiKey?.trim();
    return loaded == null || loaded.isEmpty ? null : loaded;
  }

  String? _readErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return _readString(decoded, const ['error', 'message']);
      }
    } on FormatException {
      return null;
    }

    return null;
  }

  List<dynamic> _extractList(Object? decoded) {
    if (decoded is List<dynamic>) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      for (final key in const ['data', 'skills', 'items', 'results']) {
        final value = decoded[key];
        if (value is List<dynamic>) {
          return value;
        }
      }
    }

    return const [];
  }

  Map<String, dynamic> _extractDetail(Map<String, dynamic> decoded) {
    for (final key in const ['data', 'skill', 'item', 'result']) {
      final value = decoded[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }

    return decoded;
  }

  PromptItem? _skillFromJson(Map<String, dynamic> json) {
    final title = _readString(json, const ['name', 'title', 'displayName']);
    if (title == null || title.trim().isEmpty) {
      return null;
    }

    final marketId = _readString(json, const ['id', 'slug', 'name']) ?? title;
    final description =
        _readString(json, const [
          'description',
          'summary',
          'shortDescription',
        ]) ??
        'Skill from the skills.sh market.';
    final content =
        _readSkillContent(json) ??
        _readString(json, const [
          'prompt',
          'content',
          'instructions',
          'readme',
        ]) ??
        description;
    final source = _readString(json, const ['source']);
    final author =
        _readString(json, const ['author', 'owner', 'publisher']) ??
        source?.split('/').first;

    return PromptItem(
      id: 'market-${marketId.trim()}',
      title: title.trim(),
      description: description.trim(),
      content: content.trim(),
      kind: PromptKind.skill,
      scope: PromptScope.project,
      enabledAgents: const {},
      enabledProjectIds: const {},
      source: 'skills.sh',
      author: author,
      marketId: marketId.trim(),
      marketSource: source,
      marketUrl: _readString(json, const ['url', 'homepage', 'skillUrl']),
      installUrl: _readString(json, const ['installUrl', 'install_url']),
      installs: _readInt(json, const ['installs', 'installCount', 'downloads']),
      sourceType: _readString(json, const ['sourceType', 'source_type']),
      isDuplicate: _readBool(json, const ['isDuplicate', 'duplicate']),
      isVerified: _readBool(json, const [
        'isVerified',
        'verified',
        'safe',
        'trusted',
      ]),
      hash: _readString(json, const ['hash', 'checksum']),
      marketFiles: _readSkillFiles(json),
    );
  }

  String? _readSkillContent(Map<String, dynamic> json) {
    final directFiles = json['files'];
    final directContent = _contentFromFiles(directFiles);
    if (directContent != null) {
      return directContent;
    }

    final skill = json['skill'];
    if (skill is Map<String, dynamic>) {
      return _contentFromFiles(skill['files']) ??
          _readString(skill, const ['prompt', 'content', 'instructions']);
    }

    return null;
  }

  List<SkillFile> _readSkillFiles(Map<String, dynamic> json) {
    final files = <SkillFile>[];
    _appendSkillFiles(files, json['files']);

    final skill = json['skill'];
    if (skill is Map<String, dynamic>) {
      _appendSkillFiles(files, skill['files']);
    }

    final seen = <String>{};
    return [
      for (final file in files)
        if (seen.add(file.path)) file,
    ];
  }

  void _appendSkillFiles(List<SkillFile> files, Object? value) {
    if (value is Map<String, dynamic>) {
      for (final entry in value.entries) {
        final path = entry.key.trim();
        final contents = _readFileContent(entry.value);
        if (path.isNotEmpty && contents != null) {
          files.add(SkillFile(path: path, contents: contents));
        }
      }
      return;
    }

    if (value is List<dynamic>) {
      for (final item in value.whereType<Map<String, dynamic>>()) {
        final path = _readString(item, const ['path', 'name']);
        final contents = _readFileContent(item);
        if (path != null && contents != null) {
          files.add(SkillFile(path: path, contents: contents));
        }
      }
    }
  }

  Iterable<PromptItem> _filterHtmlSkills(
    List<PromptItem> skills,
    String query,
  ) {
    if (query.isEmpty) {
      return skills;
    }

    final normalized = query.toLowerCase();
    return skills.where(
      (skill) =>
          skill.title.toLowerCase().contains(normalized) ||
          skill.description.toLowerCase().contains(normalized) ||
          (skill.marketSource?.toLowerCase().contains(normalized) ?? false),
    );
  }

  List<PromptItem> _skillsFromHtml(String html) {
    final links = RegExp(
      r'<a\b[^>]*href=["'
      ']([^"'
      ']+)["'
      '][^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);
    final skills = <PromptItem>[];
    final seenIds = <String>{};

    for (final match in links) {
      final href = _decodeHtmlEntities(match.group(1) ?? '').trim();
      final source = _sourceFromSkillPath(href);
      if (source == null) {
        continue;
      }

      final id = _marketIdFromSource(source);
      if (!seenIds.add(id)) {
        continue;
      }

      final linkHtml = match.group(2) ?? '';
      final text = _normalizeHtmlText(linkHtml);
      final title = _htmlSkillTitle(linkHtml) ?? _titleFromSource(source);
      final sourceDirectory = _sourceDirectory(source);
      final installs =
          _readInstallsFromText(text) ?? _readTrailingCompactCount(text);
      final isVerified = _hasSafetyBadge(linkHtml);
      final description = _htmlSkillDescription(
        text,
        title: title,
        sourceDirectory: sourceDirectory,
        installs: installs,
      );

      skills.add(
        PromptItem(
          id: 'market-$id',
          title: title,
          description: description.isEmpty
              ? 'Skill from the skills.sh market.'
              : description,
          content: description.isEmpty
              ? 'Skill from the skills.sh market.'
              : description,
          kind: PromptKind.skill,
          scope: PromptScope.project,
          enabledAgents: const {},
          enabledProjectIds: const {},
          source: 'skills.sh',
          author: source.split('/').first,
          marketId: id,
          marketSource: source,
          marketUrl: 'https://skills.sh/$source',
          installs: installs,
          isVerified: isVerified,
        ),
      );
    }

    return skills;
  }

  PromptItem _skillDetailsFromHtml(PromptItem item, String html) {
    final title = _firstTextAfterLabel(html, 'Title') ?? item.title;
    final summary = _firstTextAfterLabel(html, 'Summary') ?? item.description;
    final content = _skillMarkdownFromHtml(html) ?? item.content;

    return item.copyWith(
      title: title,
      description: summary,
      content: content,
      marketUrl: item.marketUrl ?? 'https://skills.sh/${_htmlDetailPath(item)}',
    );
  }

  String _htmlDetailPath(PromptItem item) {
    final source = item.marketSource;
    if (source != null && source.trim().isNotEmpty) {
      return source.startsWith('/') ? source : '/$source';
    }

    return '/${item.marketId ?? item.id.replaceFirst('market-', '')}';
  }

  String? _sourceFromSkillPath(String href) {
    final uri = Uri.tryParse(href);
    final path = uri?.path ?? href.split('?').first.split('#').first;
    final segments = path
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();

    if (segments.length < 3 || segments[1] != 'skills') {
      return null;
    }

    return '${segments[0]}/skills/${segments[2]}';
  }

  String _marketIdFromSource(String source) {
    return source
        .replaceAll('/', '-')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');
  }

  String _titleFromSource(String source) {
    final slug = source.split('/').last;
    return slug
        .split(RegExp('[-_]'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String? _firstTextAfterLabel(String html, String label) {
    final pattern = RegExp(
      '$label\\s*</[^>]+>\\s*<[^>]+>(.*?)</[^>]+>',
      caseSensitive: false,
      dotAll: true,
    );
    final match = pattern.firstMatch(html);
    if (match == null) {
      return null;
    }

    final text = _normalizeHtmlText(match.group(1) ?? '');
    return text.isEmpty ? null : text;
  }

  String? _skillMarkdownFromHtml(String html) {
    final headingMatch = RegExp(
      r'SKILL\.md',
      caseSensitive: false,
    ).firstMatch(html);
    if (headingMatch == null) {
      return null;
    }

    final afterHeading = html.substring(headingMatch.end);
    final codeMatch = RegExp(
      r'<(?:pre|code)\b[^>]*>(.*?)</(?:pre|code)>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(afterHeading);
    if (codeMatch == null) {
      return null;
    }

    final text = _normalizeHtmlText(codeMatch.group(1) ?? '');
    return text.isEmpty ? null : text;
  }

  String _normalizeHtmlText(String html) {
    final withoutScripts = html
        .replaceAll(RegExp(r'<script\b[^>]*>.*?</script>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<style\b[^>]*>.*?</style>', dotAll: true), ' ');
    return _decodeHtmlEntities(
      withoutScripts.replaceAll(RegExp(r'<[^>]+>'), ' '),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  int? _readInstallsFromText(String text) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?\s*[kKmM]?)\s+installs?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return null;
    }

    return _parseCompactCount(match.group(1) ?? '');
  }

  int? _readTrailingCompactCount(String text) {
    final matches = RegExp(
      r'\b\d+(?:\.\d+)?\s*[kKmM]?\b',
    ).allMatches(text).toList();
    if (matches.isEmpty) {
      return null;
    }

    return _parseCompactCount(matches.last.group(0) ?? '');
  }

  String? _htmlSkillTitle(String html) {
    final match = RegExp(
      r'<h[1-6]\b[^>]*>(.*?)</h[1-6]>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) {
      return null;
    }

    final title = _normalizeHtmlText(match.group(1) ?? '');
    return title.isEmpty ? null : title;
  }

  bool _hasSafetyBadge(String html) {
    return RegExp(r'<svg\b', caseSensitive: false).hasMatch(html);
  }

  String _sourceDirectory(String source) {
    final segments = source
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    if (segments.length <= 1) {
      return source;
    }

    return segments.take(segments.length - 1).join('/');
  }

  String _htmlSkillDescription(
    String text, {
    required String title,
    required String sourceDirectory,
    required int? installs,
  }) {
    var description = _stripInstallText(text)
        .replaceFirst(RegExp(r'^\d+\s+'), '')
        .replaceFirst(RegExp(RegExp.escape(title), caseSensitive: false), '')
        .replaceFirst(
          RegExp(RegExp.escape(sourceDirectory), caseSensitive: false),
          '',
        )
        .trim();

    if (installs != null) {
      description = description
          .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\s*[kKmM]?\b'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    return description;
  }

  String _stripInstallText(String text) {
    return text
        .replaceAll(
          RegExp(
            r'\b\d+(?:\.\d+)?\s*[kKmM]?\s+installs?\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int? _parseCompactCount(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (normalized.isEmpty) {
      return null;
    }

    final suffix = normalized.substring(normalized.length - 1).toLowerCase();
    final hasSuffix = suffix == 'k' || suffix == 'm';
    final numberText = hasSuffix
        ? normalized.substring(0, normalized.length - 1).trim()
        : normalized;
    final number = double.tryParse(numberText);
    if (number == null) {
      return null;
    }

    final multiplier = switch (suffix) {
      'k' => 1000,
      'm' => 1000000,
      _ => 1,
    };
    return (number * multiplier).round();
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  String? _contentFromFiles(Object? files) {
    if (files is Map<String, dynamic>) {
      final skillMd = _readFileContent(files['SKILL.md']);
      if (skillMd != null) {
        return skillMd;
      }

      for (final entry in files.entries) {
        if (entry.key.toLowerCase().endsWith('skill.md')) {
          final content = _readFileContent(entry.value);
          if (content != null) {
            return content;
          }
        }
      }

      for (final value in files.values) {
        final content = _readFileContent(value);
        if (content != null) {
          return content;
        }
      }
    }

    if (files is List<dynamic>) {
      for (final file in files.whereType<Map<String, dynamic>>()) {
        final name = _readString(file, const ['name', 'path']);
        if (name != null && name.toLowerCase().endsWith('skill.md')) {
          final content = _readFileContent(file);
          if (content != null) {
            return content;
          }
        }
      }

      for (final file in files) {
        final content = _readFileContent(file);
        if (content != null) {
          return content;
        }
      }
    }

    return null;
  }

  String? _readFileContent(Object? file) {
    if (file is String && file.trim().isNotEmpty) {
      return file.trim();
    }

    if (file is Map<String, dynamic>) {
      return _readString(file, const ['contents', 'content', 'text', 'body']);
    }

    return null;
  }

  String? _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }

      if (value is num) {
        return '$value';
      }

      if (value is Map<String, dynamic>) {
        final nestedValue = _readString(value, const [
          'name',
          'login',
          'title',
          'username',
        ]);
        if (nestedValue != null) {
          return nestedValue;
        }
      }
    }

    return null;
  }

  int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) {
        return value;
      }

      if (value is num) {
        return value.round();
      }

      if (value is String) {
        return int.tryParse(value);
      }
    }

    return null;
  }

  bool _readBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) {
        return value;
      }

      if (value is String) {
        return value.toLowerCase() == 'true';
      }
    }

    return false;
  }
}
