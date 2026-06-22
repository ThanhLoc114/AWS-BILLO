import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/features/admin/admin_shell.dart';

void main() {
  testWidgets('Admin approve flow updates status in list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminShell()));

    await tester.tap(find.byKey(const Key('admin_item_APP001')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Chi tiết hồ sơ #APP001'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin_approve_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('APPROVED'), findsWidgets);
  });

  testWidgets('Admin reject flow updates status in list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminShell()));

    await tester.tap(find.byKey(const Key('admin_item_APP001')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin_reject_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('REJECTED'), findsWidgets);
  });
}
