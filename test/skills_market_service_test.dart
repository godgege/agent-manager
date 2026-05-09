import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_manager/models/prompt_item.dart';
import 'package:agent_manager/services/skills_market_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fetchSkills uses search endpoint when query is provided', () async {
    final client = _FakeHttpClient({
      '/api/v1/skills/search?q=review&limit=50&offset=0': jsonEncode({
        'data': [
          {
            'id': 'code-review',
            'name': 'Code Review',
            'description': 'Review code changes.',
            'source': 'octocat/code-review',
            'installs': 1200,
          },
        ],
        'pagination': {'total': 1, 'limit': 50, 'offset': 0},
      }),
    });

    final service = SkillsMarketService(httpClient: client);
    final skills = await service.fetchSkills(query: 'review');

    expect(client.requestedUris.single.path, '/api/v1/skills/search');
    expect(client.requestedUris.single.queryParameters['q'], 'review');
    expect(skills.single.marketId, 'code-review');
    expect(skills.single.title, 'Code Review');
    expect(skills.single.author, 'octocat');
    expect(skills.single.installs, 1200);
  });

  test('fetchSkills sends bearer token when api key is configured', () async {
    final client = _FakeHttpClient({
      '/api/v1/skills?limit=50&offset=0': jsonEncode({
        'data': [
          {
            'id': 'code-review',
            'name': 'Code Review',
            'description': 'Review code changes.',
          },
        ],
      }),
    });

    final service = SkillsMarketService(
      httpClient: client,
      apiKey: 'test-api-key',
    );
    await service.fetchSkills();

    expect(
      client.requests.single.headerValues[HttpHeaders.authorizationHeader],
      ['Bearer test-api-key'],
    );
  });

  test('fetchSkillDetails reads SKILL.md contents from detail files', () async {
    final client = _FakeHttpClient({
      '/api/v1/skills/code-review': jsonEncode({
        'data': {
          'id': 'code-review',
          'name': 'Code Review',
          'description': 'Review code changes.',
          'files': [
            {'path': 'SKILL.md', 'contents': 'Use contents field.'},
          ],
        },
      }),
    });

    final service = SkillsMarketService(httpClient: client);
    final item = await service.fetchSkillDetails(
      PromptItem(
        id: 'market-code-review',
        title: 'Code Review',
        description: 'Review code changes.',
        content: 'Review code changes.',
        kind: PromptKind.skill,
        scope: PromptScope.project,
        enabledAgents: const {},
        enabledProjectIds: const {},
        source: 'skills.sh',
        marketId: 'code-review',
      ),
    );

    expect(item.content, 'Use contents field.');
    expect(item.marketFiles.single.path, 'SKILL.md');
    expect(item.marketFiles.single.contents, 'Use contents field.');
  });

  test('fetchSkillDetails reads SKILL.md from detail files', () async {
    final client = _FakeHttpClient({
      '/api/v1/skills/code-review': jsonEncode({
        'data': {
          'id': 'code-review',
          'name': 'Code Review',
          'description': 'Review code changes.',
          'files': [
            {'path': 'README.md', 'content': 'Ignore me'},
            {'path': 'SKILL.md', 'content': 'Use this review workflow.'},
          ],
        },
      }),
    });

    final service = SkillsMarketService(httpClient: client);
    final item = await service.fetchSkillDetails(
      PromptItem(
        id: 'market-code-review',
        title: 'Code Review',
        description: 'Review code changes.',
        content: 'Review code changes.',
        kind: PromptKind.skill,
        scope: PromptScope.project,
        enabledAgents: const {},
        enabledProjectIds: const {},
        source: 'skills.sh',
        marketId: 'code-review',
      ),
    );

    expect(item.content, 'Use this review workflow.');
    expect(item.id, 'market-code-review');
  });

  test('fetchSkills falls back to parsing skills.sh html', () async {
    final client = _FakeHttpClient({
      '/api/v1/skills?limit=50&offset=0': _FakeResponse(
        body: jsonEncode({'error': 'api unavailable'}),
        statusCode: HttpStatus.internalServerError,
      ),
      '/': const _FakeResponse(
        body: '''
          <main>
            <a href="/vercel-labs/skills/find-skills">
              <div><span>1</span></div>
              <div>
                <h3>find-skills</h3>
                <p>vercel-labs/skills</p>
              </div>
              <div>
                <svg></svg>
                <span>1.4M</span>
              </div>
            </a>
            <a href="/openai/skills/docs-writer">
              <h2>Docs Writer</h2>
              <p>Write concise project documentation.</p>
              <span>42 installs</span>
            </a>
          </main>
        ''',
      ),
    });

    final service = SkillsMarketService(httpClient: client);
    final skills = await service.fetchSkills();

    expect(skills, hasLength(2));
    expect(skills.first.marketId, 'vercel-labs-skills-find-skills');
    expect(skills.first.marketSource, 'vercel-labs/skills/find-skills');
    expect(skills.first.title, 'find-skills');
    expect(skills.first.description, isNot(contains('installs')));
    expect(skills.first.description, isNot(contains('vercel-labs/skills')));
    expect(skills.first.installs, 1400000);
    expect(skills.first.isVerified, isTrue);
    expect(skills.last.installs, 42);
    expect(skills.last.isVerified, isFalse);
  });

  test('fetchSkillDetails falls back to parsing skill html page', () async {
    final client = _FakeHttpClient({
      '/api/v1/skills/anthropic-skills-code-review': _FakeResponse(
        body: jsonEncode({'error': 'api unavailable'}),
        statusCode: HttpStatus.internalServerError,
      ),
      '/anthropic/skills/code-review': const _FakeResponse(
        body: '''
          <section>
            <h3>Title</h3>
            <p>Code Review</p>
            <h3>Summary</h3>
            <p>Review pull requests with structured feedback.</p>
            <h3>SKILL.md</h3>
            <pre>Use this HTML fallback workflow.</pre>
          </section>
        ''',
      ),
    });

    final service = SkillsMarketService(httpClient: client);
    final item = await service.fetchSkillDetails(
      PromptItem(
        id: 'market-anthropic-skills-code-review',
        title: 'Code Review',
        description: 'Review pull requests.',
        content: 'Review pull requests.',
        kind: PromptKind.skill,
        scope: PromptScope.project,
        enabledAgents: const {},
        enabledProjectIds: const {},
        source: 'skills.sh',
        marketId: 'anthropic-skills-code-review',
        marketSource: 'anthropic/skills/code-review',
      ),
    );

    expect(item.description, 'Review pull requests with structured feedback.');
    expect(item.content, 'Use this HTML fallback workflow.');
  });
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this.responses);

  final Map<String, Object> responses;
  final List<Uri> requestedUris = [];
  final List<_FakeHttpClientRequest> requests = [];

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestedUris.add(url);
    final response =
        responses[url.path + (url.hasQuery ? '?${url.query}' : '')] ??
        responses[url.path] ??
        '{}';
    final request = _FakeHttpClientRequest(
      response is _FakeResponse ? response : _FakeResponse(body: '$response'),
    );
    requests.add(request);
    return request;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.response);

  final _FakeResponse response;
  final _FakeHttpHeaders _headers = _FakeHttpHeaders();

  Map<String, List<String>> get headerValues => _headers.values;

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse(response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(_FakeResponse response)
    : _statusCode = response.statusCode,
      _bytes = utf8.encode(response.body);

  final List<int> _bytes;
  final int _statusCode;

  @override
  int get statusCode => _statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_bytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse {
  const _FakeResponse({required this.body, this.statusCode = HttpStatus.ok});

  final String body;
  final int statusCode;
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> values = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = [value.toString()];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
