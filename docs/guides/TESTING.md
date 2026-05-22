# CloudStream Testing Guide

> How to write tests, run them, and maintain coverage.

---

## Testing Philosophy

CloudStream tests serve two purposes:

1. **Confidence** — you can ship without manually testing every edge case
2. **Documentation** — tests show how code is *supposed* to behave

**Rule:** If it can break, it must have a test. P0 bugs (crashes, data loss) are zero-tolerance — there must be a test for every P0 scenario.

---

## Test Types

| Type | Purpose | Run With |
|------|---------|----------|
| Unit tests | Test a single function/class in isolation | `flutter test` |
| Widget tests | Test a single widget's rendering | `flutter test` |
| Integration tests | Test a full user flow | `flutter test integration_test/` |
| Golden tests | Test UI hasn't changed visually | `flutter test` |

---

## Test Structure

```
apps/cloudstream_app/
├── test/
│   ├── unit/              # Unit tests
│   │   ├── repositories/
│   │   ├── services/
│   │   └── utils/
│   ├── widget/            # Widget tests
│   │   ├── components/
│   │   └── pages/
│   └── integration/       # Integration tests
│       └── flows/
└── test_helpers/
    ├── mock_clients/
    └── test_utils.dart
```

---

## Running Tests

```bash
# All unit + widget tests
flutter test

# Specific file
flutter test test/unit/services/channel_repository_test.dart

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Integration tests (requires device/simulator)
flutter test integration_test/onboarding_test.dart
```

---

## Unit Test Conventions

```dart
// Use mocktail for mocking
import 'package:mocktail/mocktail.dart';

// Register fallback values for any() matchers
setUpAll(() {
  registerFallbackValue(Uri.parse('https://example.com'));
});

// Group related tests
group('ChannelRepository', () {
  late ChannelRepository repository;
  late MockXtreamApiClient mockClient;

  setUp(() {
    mockClient = MockXtreamApiClient();
    repository = ChannelRepository(client: mockClient);
  });

  test('getStreamUrl returns cached URL if not expired', () async {
    // Arrange
    when(() => mockClient.getStreamUrl(any()))
        .thenAnswer((_) async => 'https://stream.example.com/live.m3u8');

    // Act
    final url = await repository.getStreamUrl('channel-123');

    // Assert
    expect(url, contains('m3u8'));
    verify(() => mockClient.getStreamUrl('channel-123')).called(1);
  });
});
```

---

## Widget Test Conventions

```dart
testWidgets('CSChannelTile shows channel name and logo', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CSChannelTile(
        channel: Channel(id: '1', name: 'BBC One', logoUrl: 'https://...'),
        onTap: () {},
      ),
    ),
  );

  expect(find.text('BBC One'), findsOneWidget);
  expect(find.byType(Image), findsOneWidget);
});
```

---

## Integration Test Conventions

```dart
testWidgets('User can add Xtream server and see channels', (tester) async {
  // Start app
  await tester.pumpWidget(const CloudStreamApp());
  await tester.pumpAndSettle();

  // Navigate to settings
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();

  // Enter server details
  await tester.enterText(
    find.byType(CSTextField).first,
    'https://server.example.com',
  );

  // Submit
  await tester.tap(find.text('Connect'));
  await tester.pumpAndSettle();

  // Verify channels appear
  expect(find.byType(CSChannelTile), findsWidgets);
});
```

---

## Coverage Requirements

| Code Type | Minimum Coverage |
|-----------|----------------|
| Business logic (repositories, services) | 80% |
| Use cases | 90% |
| UI widgets | 50% |
| API clients | 70% |

Coverage is tracked in CI. PRs that drop coverage below these thresholds will fail CI.

---

## Mocking External Services

### Xtream API

```dart
class MockXtreamApiClient extends Mock implements XtreamApiClient {}
```

Use `mocktail` — no need for code generation.

### Firebase

Firebase cannot be easily unit tested. Use integration tests with a Firebase Local Emulator for Firebase-dependent code.

```bash
# Start Firebase emulators
firebase emulators:start
```

---

## Writing Testable Code

**Dependency inject everything:**

```dart
// Good: injectable dependency
class ChannelRepository {
  final XtreamApiClient client;
  ChannelRepository({required this.client});
}

// Bad: hard-coded dependency
class ChannelRepository {
  final client = XtreamApiClient(); // hard to mock
}
```

**Prefer pure functions in business logic:**

```dart
// Good: pure function, easy to test
Duration calculateRemainingTime(Position position, Duration total) {
  return total - position;
}

// Bad: has side effects, harder to test
Duration getRemainingTime() {
  final position = player.position; // hidden dependency
  return total - position;
}
```

---

## CI Test Execution

Tests run on every PR via GitHub Actions:

```yaml
- name: Run tests
  run: flutter test --no-pub
```

Tests that take > 5 minutes will fail CI. Optimise slow tests by:
- Using `FakeAsync` instead of real async delays
- Mocking network calls instead of making real HTTP requests
- Using `setUpAll` for expensive setup that's shared across tests

---

## Related Docs

- [DEVELOPMENT.md](DEVELOPMENT.md) — Local setup
- [CODE_REVIEW.md](CODE_REVIEW.md) — Review checklist
