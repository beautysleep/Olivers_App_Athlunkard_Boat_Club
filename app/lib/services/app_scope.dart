/// Exposes [AppState] to the widget tree and rebuilds dependents when it
/// changes — a tiny dependency-free alternative to provider/riverpod for the
/// demo. Any widget calling `AppScope.of(context)` rebuilds on notifyListeners.
library;

import 'package:flutter/widgets.dart';

import 'app_state.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState appState,
    required super.child,
  }) : super(notifier: appState);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in the widget tree');
    return scope!.notifier!;
  }
}
