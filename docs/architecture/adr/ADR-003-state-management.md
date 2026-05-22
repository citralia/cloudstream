# ADR-003: Riverpod 2.x for State Management

**Status:** Accepted
**Date:** 2026-05-22
**Deciders:** Engineering team

---

## Context

Flutter state management options are numerous: Provider, Riverpod, BLoC, GetX, MobX, ChangeNotifier, setState. We needed something that:

- Works well with async data (network requests, streams)
- Supports dependency injection cleanly
- Enables testability without complex mocking
- Scales from simple UI state to complex player state
- Has good tooling and a strong ecosystem

---

## Decision

**Riverpod 2.x** (Flutter package: `flutter_riverpod`)

Key reasons:
- **Compile-safe:** Riverpod generates providers at compile time — errors are caught before runtime, not at runtime
- **Testability:** providers are just functions; mocking is trivial
- **No context dependency:** providers are accessed outside widget tree, eliminating context drilling
- **Async support:** first-class `AsyncValue` handling for loading/error/data states
- **Code generation optional:** can use `@riverpod` annotations, but hand-written providers work fine
- **Ecosystem:** widely adopted, stable, well-documented

---

## Consequences

**Better:**
- Cleaner separation between UI and business logic
- Easy to share state across distant widget subtrees
- `ref.watch` / `ref.read` pattern is explicit and readable
- Providers are trivially mockable in tests
- State not tied to widget lifecycle — survives orientation changes, navigation

**Worse:**
- New mental model for developers used to `setState` — learning curve
- Riverpod's API surface is large — need to standardise on patterns (see conventions below)

**Conventions established:**
```
Providers are always named: <feature><State|Notifier|Provider>
StateNotifierProvider → for complex mutable state
FutureProvider / StreamProvider → for async data
StateProvider → for simple UI state (used sparingly)
```

---

## Alternatives Considered

### BLoC

Rejected because: BLoC requires significant boilerplate (events, states, blocs). For a video player with complex async state (buffering, playing, errors, position), the ceremony outweighs the value. Riverpod is more ergonomic.

### GetX

Rejected because: GetX's magic (controllers, reactive state, dependency injection all in one) creates隐性 coupling that's hard to trace. It works, but the "magic" makes it hard for new engineers to understand what's happening. Riverpod is explicit.

### Provider (vanilla)

Rejected because: Provider's main limitation is that it depends on `BuildContext` for access, making it harder to test and creating coupling between the widget tree and state. Riverpod fixes this.
