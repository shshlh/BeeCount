// 7.13.2 搜索页三层筛选选择器：类型选择 + 一级/二级分类展开选择 + 转账。
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/widgets/biz/search_category_filter_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
    final incomeParent = await repo.createCategory(name: '工资', kind: 'income');
    await repo.createSubCategory(
        parentId: incomeParent, name: '奖金', kind: 'income');
    await repo.createCategory(name: '餐饮', kind: 'expense');
  });

  tearDown(() async => db.close());

  Future<SearchCategoryFilterResult? Function()> pumpDialog(
      WidgetTester tester) async {
    SearchCategoryFilterResult? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showSearchCategoryFilter(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    return () => result;
  }

  testWidgets('选择转账直接返回类型筛选', (tester) async {
    final getResult = await pumpDialog(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('转账'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    final result = getResult();
    expect(result?.type, 'transfer');
    expect(result?.category, isNull);
  });

  testWidgets('收入类型下展开一级分类并选择二级分类', (tester) async {
    final getResult = await pumpDialog(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工资'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('奖金'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    final result = getResult();
    expect(result?.type, 'income');
    expect(result?.category?.name, '奖金');
  });

  testWidgets('未选类型显示中性提示，选转账后显示转账无分类', (tester) async {
    final getResult = await pumpDialog(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('请选择收入/支出/转账'), findsOneWidget);
    expect(find.text('转账无分类，直接按类型筛选'), findsNothing);

    await tester.tap(find.text('转账'));
    await tester.pumpAndSettle();
    expect(find.text('请选择收入/支出/转账'), findsNothing);
    expect(find.text('转账无分类，直接按类型筛选'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(getResult()?.type, 'transfer');
  });
}
