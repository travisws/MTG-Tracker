import 'package:flutter/widgets.dart';

import 'session_store.dart';

class SessionScope extends InheritedNotifier<SessionStore> {
  const SessionScope({
    required SessionStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  static SessionStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope found in context');
    return scope!.notifier!;
  }
}
