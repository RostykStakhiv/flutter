// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class TestAction extends Action {
  TestAction() : super(key);

  static const LocalKey key = ValueKey<Type>(TestAction);

  int calls = 0;

  @override
  void invoke(FocusNode node, Intent intent) {
    calls += 1;
  }
}

void main() {
  testWidgets('WidgetsApp with builder only', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      WidgetsApp(
        key: key,
        builder: (BuildContext context, Widget child) {
          return const Placeholder();
        },
        color: const Color(0xFF123456),
      ),
    );
    expect(find.byKey(key), findsOneWidget);
  });

  testWidgets('WidgetsApp can override default key bindings', (WidgetTester tester) async {
    bool checked = false;
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      WidgetsApp(
        key: key,
        builder: (BuildContext context, Widget child) {
          return Material(
            child: Checkbox(
              value: checked,
              autofocus: true,
              onChanged: (bool value) {
                checked = value;
              },
            ),
          );
        },
        color: const Color(0xFF123456),
      ),
    );
    await tester.pump(); // Wait for focus to take effect.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    // Default key mapping worked.
    expect(checked, isTrue);
    checked = false;

    final TestAction action = TestAction();
    await tester.pumpWidget(
      WidgetsApp(
        key: key,
        actions: <LocalKey, ActionFactory>{
          TestAction.key: () => action,
        },
        shortcuts: <LogicalKeySet, Intent> {
          LogicalKeySet(LogicalKeyboardKey.space): const Intent(TestAction.key),
        },
        builder: (BuildContext context, Widget child) {
          return Material(
            child: Checkbox(
              value: checked,
              autofocus: true,
              onChanged: (bool value) {
                checked = value;
              },
            ),
          );
        },
        color: const Color(0xFF123456),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    // Default key mapping was not invoked.
    expect(checked, isFalse);
    // Overridden mapping was invoked.
    expect(action.calls, equals(1));
  });

  group('error control test', () {
    Future<void> expectFlutterError({
      GlobalKey<NavigatorState> key,
      Widget widget,
      WidgetTester tester,
      String errorMessage,
    }) async {
      await tester.pumpWidget(widget);
      FlutterError error;
      try {
        key.currentState.pushNamed('/path');
      } on FlutterError catch (e) {
        error = e;
      } finally {
        expect(error, isNotNull);
        expect(error, isFlutterError);
        expect(error.toStringDeep(), errorMessage);
      }
    }

    testWidgets('push unknown route when onUnknownRoute is null', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      expectFlutterError(
        key: key,
        tester: tester,
        widget: MaterialApp(
          navigatorKey: key,
          home: Container(),
          onGenerateRoute: (_) => null,
        ),
        errorMessage:
          'FlutterError\n'
          '   Could not find a generator for route RouteSettings("/path", null)\n'
          '   in the _WidgetsAppState.\n'
          '   Generators for routes are searched for in the following order:\n'
          '    1. For the "/" route, the "home" property, if non-null, is used.\n'
          '    2. Otherwise, the "routes" table is used, if it has an entry for\n'
          '   the route.\n'
          '    3. Otherwise, onGenerateRoute is called. It should return a\n'
          '   non-null value for any valid route not handled by "home" and\n'
          '   "routes".\n'
          '    4. Finally if all else fails onUnknownRoute is called.\n'
          '   Unfortunately, onUnknownRoute was not set.\n',
      );
    });

    testWidgets('push unknown route when onUnknownRoute returns null', (WidgetTester tester) async {
      final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
      expectFlutterError(
        key: key,
        tester: tester,
        widget: MaterialApp(
          navigatorKey: key,
          home: Container(),
          onGenerateRoute: (_) => null,
          onUnknownRoute: (_) => null,
        ),
        errorMessage:
          'FlutterError\n'
          '   The onUnknownRoute callback returned null.\n'
          '   When the _WidgetsAppState requested the route\n'
          '   RouteSettings("/path", null) from its onUnknownRoute callback,\n'
          '   the callback returned null. Such callbacks must never return\n'
          '   null.\n' ,
      );
    });
  });

  testWidgets('WidgetsApp can customize initial routes', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      WidgetsApp(
        navigatorKey: navigatorKey,
        onGenerateInitialRoutes: (String initialRoute) {
          expect(initialRoute, '/abc');
          return <Route<void>>[
            PageRouteBuilder<void>(
              pageBuilder: (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation) {
                return const Text('non-regular page one');
              }
            ),
            PageRouteBuilder<void>(
              pageBuilder: (
                BuildContext context,
                Animation<double> animation,
                Animation<double> secondaryAnimation) {
                return const Text('non-regular page two');
              }
            ),
          ];
        },
        initialRoute: '/abc',
        onGenerateRoute: (RouteSettings settings) {
          return PageRouteBuilder<void>(
            pageBuilder: (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation) {
              return const Text('regular page');
            }
          );
        },
        color: const Color(0xFF123456),
      )
    );
    expect(find.text('non-regular page two'), findsOneWidget);
    expect(find.text('non-regular page one'), findsNothing);
    expect(find.text('regular page'), findsNothing);
    navigatorKey.currentState.pop();
    await tester.pumpAndSettle();
    expect(find.text('non-regular page two'), findsNothing);
    expect(find.text('non-regular page one'), findsOneWidget);
    expect(find.text('regular page'), findsNothing);
  });
}
