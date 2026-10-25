import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grinch/local_pin_gate.dart';
import 'package:grinch/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app starts behind the local PIN gate', (tester) async {
    await tester.pumpWidget(const GrinchApp());
    await tester.pumpAndSettle();

    expect(find.text('Crea tu PIN'), findsOneWidget);
    expect(find.text('Saldo por recuperar'), findsNothing);
  });

  testWidgets('appearance changes apply immediately and persist', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'jean_lucas_local_pin': '1234',
    });
    await tester.pumpWidget(const GrinchApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configuración').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Modo noche'))).brightness,
      Brightness.dark,
    );
    expect(
      (await SharedPreferences.getInstance()).getBool('jean_lucas_dark_mode'),
      isTrue,
    );

    await tester.tap(find.text('Apariencia').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appearance-color-2')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('appearance-text-scale-2')),
    );
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getInt('jean_lucas_theme_color'), 2);
    expect(preferences.getInt('jean_lucas_text_scale'), 2);
    expect(
      MediaQuery.textScalerOf(
        tester.element(
          find.byKey(const ValueKey('appearance-text-scale-2')),
        ),
      ).scale(10),
      closeTo(11.2, 0.01),
    );
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('appearance-color-2'))),
      ).colorScheme.primary,
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF7755C9),
        brightness: Brightness.dark,
      ).primary,
    );
  });

  testWidgets(
    'first launch creates a four-digit PIN before opening the dashboard',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LocalPinGate(child: Text('Contenido local protegido')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Crea tu PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();
      expect(find.text('Confirma tu PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();

      expect(
        (await SharedPreferences.getInstance()).getString(
          'jean_lucas_local_pin',
        ),
        '1234',
      );
      expect(find.text('Contenido local protegido'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(
          home: LocalPinGate(child: Text('Contenido local protegido')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ingresa tu PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();
      expect(find.text('Contenido local protegido'), findsOneWidget);
    },
  );

  testWidgets('saved PIN is required to open the local app', (tester) async {
    SharedPreferences.setMockInitialValues({'jean_lucas_local_pin': '5678'});
    await tester.pumpWidget(
      const MaterialApp(
        home: LocalPinGate(child: Text('Contenido local protegido')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0000');
    await tester.pumpAndSettle();
    expect(find.text('PIN incorrecto. Inténtalo de nuevo.'), findsOneWidget);
    expect(find.text('Contenido local protegido'), findsNothing);

    await tester.enterText(find.byType(TextField), '5678');
    await tester.pumpAndSettle();
    expect(find.text('Contenido local protegido'), findsOneWidget);
  });

  testWidgets('app asks for PIN again after leaving and returning', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'jean_lucas_local_pin': '5678'});
    await tester.pumpWidget(
      const MaterialApp(
        home: LocalPinGate(child: Text('Contenido local protegido')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '5678');
    await tester.pumpAndSettle();
    expect(find.text('Contenido local protegido'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu PIN'), findsOneWidget);
    expect(find.text('Contenido local protegido'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '5678');
    await tester.pumpAndSettle();
    expect(find.text('Contenido local protegido'), findsOneWidget);
  });

  testWidgets('jean luca credit app loads dashboard', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    expect(find.text('JEAN LUCAS CREDIT'), findsOneWidget);
    expect(find.text('Saldo por recuperar'), findsOneWidget);
    expect(find.text('Cobros próximos 30 días'), findsOneWidget);
    expect(find.text('Utilidad pendiente'), findsOneWidget);
    expect(find.text('Préstamos activos'), findsOneWidget);
    expect(find.text('Próximos cobros'), findsOneWidget);
    expect(find.text('Cartera y recuperación'), findsOneWidget);
    expect(find.byTooltip('Cotizador rápido'), findsOneWidget);
    expect(find.byTooltip('Nuevo préstamo'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('Cotizador rápido'), findsNothing);
    expect(find.text('Nuevo préstamo'), findsNothing);
  });

  testWidgets('new loan is persisted and restored after the app is recreated', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Nuevo préstamo'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Cliente guardado',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '900');
    await tester.enterText(find.byType(TextFormField).at(3), '6');
    await tester.ensureVisible(find.text('Guardar préstamo'));
    await tester.tap(find.text('Guardar préstamo'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('jean_lucas_loans')!.join(),
      contains('Cliente guardado'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Préstamos').last);
    await tester.pumpAndSettle();

    expect(find.text('Cliente guardado'), findsOneWidget);
  });

  testWidgets('loans tab shows premium brand and quick actions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Préstamos').last);
    await tester.pumpAndSettle();

    expect(find.text('Jean Lucas Credit'), findsOneWidget);
    expect(find.byTooltip('Cotizador rápido'), findsOneWidget);
    expect(find.byTooltip('Nuevo préstamo'), findsOneWidget);
    expect(find.text('Cotizador rápido'), findsNothing);
    expect(find.text('Nuevo préstamo'), findsNothing);
  });

  testWidgets('analysis tab shows portfolio profitability and quote sections', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Análisis').last);
    await tester.pumpAndSettle();

    expect(find.text('Análisis de cartera'), findsOneWidget);
    expect(find.text('Rentabilidad por préstamo'), findsOneWidget);
    expect(find.text('Cotizaciones en borrador'), findsOneWidget);
    expect(find.text('Estado de la cartera'), findsOneWidget);
  });

  test('loan and quote drafts serialize and restore', () {
    final loan = LoanRecord(
      borrowerName: 'Ana Torres',
      amount: 1200,
      interestRate: 18,
      months: 6,
      paidMonths: 2,
      date: DateTime(2026, 9, 16),
    );

    final loanJson = loan.toJson();
    final restoredLoan = LoanRecord.fromJson(loanJson);
    expect(restoredLoan.borrowerName, 'Ana Torres');
    expect(restoredLoan.totalToReceive, closeTo(1416, 0.001));

    final draft = QuoteDraft(
      borrowerName: 'Luis Pérez',
      amount: 800,
      interestRate: 15,
      months: 4,
      approved: true,
      createdAt: DateTime(2026, 9, 15),
    );

    final draftJson = draft.toJson();
    final restoredDraft = QuoteDraft.fromJson(draftJson);
    expect(restoredDraft.borrowerName, 'Luis Pérez');
    expect(restoredDraft.approved, isTrue);
    expect(restoredDraft.monthlyPayment, closeTo(230, 0.001));
  });

  test('approved quote becomes an active loan', () {
    final draft = QuoteDraft(
      borrowerName: 'Carlos Rojas',
      amount: 2000,
      interestRate: 20,
      months: 8,
    );

    final loan = draft.toLoanRecord();
    expect(loan.borrowerName, 'Carlos Rojas');
    expect(loan.amount, 2000);
    expect(loan.months, 8);
    expect(loan.totalToReceive, closeTo(2400, 0.001));
  });

  test('portfolio metrics use recorded installments and schedules', () {
    final today = DateTime.now();
    final loan = LoanRecord(
      borrowerName: 'Cliente de prueba',
      amount: 1200,
      interestRate: 20,
      months: 6,
      paidMonths: 1,
      firstPaymentDate: today,
      paymentFrequency: LoanPaymentFrequency.custom,
      customEveryDays: 2,
    );

    final metrics = PortfolioMetrics([loan]);

    expect(metrics.capital, 1200);
    expect(metrics.collected, closeTo(240, 0.001));
    expect(metrics.outstanding, closeTo(1200, 0.001));
    expect(metrics.collectedProfit, closeTo(40, 0.001));
    expect(metrics.remainingProfit, closeTo(200, 0.001));
    expect(metrics.next30DaysCollection, closeTo(1200, 0.001));
    expect(metrics.upcomingInstallments, hasLength(5));
  });

  test('loan keeps payment schedule metadata', () {
    final loan = LoanRecord(
      borrowerName: 'María López',
      amount: 1500,
      interestRate: 20,
      months: 6,
      paidMonths: 1,
      date: DateTime(2026, 9, 16),
      paymentFrequency: LoanPaymentFrequency.weekly,
      paymentWeekday: DateTime.thursday,
    );

    final restored = LoanRecord.fromJson(loan.toJson());
    expect(restored.paymentFrequency, LoanPaymentFrequency.weekly);
    expect(restored.paymentWeekday, DateTime.thursday);
    expect(restored.nextDueLabel, 'Jueves');

    final monthlyLoan = LoanRecord(
      borrowerName: 'Pedro Ruiz',
      amount: 2000,
      interestRate: 18,
      months: 4,
      paidMonths: 0,
      date: DateTime(2026, 9, 16),
      paymentFrequency: LoanPaymentFrequency.monthly,
      paymentDayOfMonth: 15,
    );

    final restoredMonthly = LoanRecord.fromJson(monthlyLoan.toJson());
    expect(restoredMonthly.paymentFrequency, LoanPaymentFrequency.monthly);
    expect(restoredMonthly.paymentDayOfMonth, 15);
    expect(restoredMonthly.nextDueLabel, 'Día 15');
  });

  test('loan status and next due date are derived consistently', () {
    final now = DateTime.now();
    final overdueLoan = LoanRecord(
      borrowerName: 'Jorge Salas',
      amount: 1500,
      interestRate: 20,
      months: 4,
      paidMonths: 1,
      date: now,
      disbursementDate: now.subtract(const Duration(days: 30)),
      firstPaymentDate: now.subtract(const Duration(days: 30)),
      paymentFrequency: LoanPaymentFrequency.monthly,
      paymentDayOfMonth: now.day,
    );

    expect(overdueLoan.status, LoanStatus.overdue);
    expect(overdueLoan.nextDueDate, isNotNull);

    final finishedLoan = LoanRecord(
      borrowerName: 'Sofía Díaz',
      amount: 1200,
      interestRate: 18,
      months: 3,
      paidMonths: 3,
      date: now,
      disbursementDate: now,
      firstPaymentDate: now,
    );

    expect(finishedLoan.status, LoanStatus.finished);
    expect(finishedLoan.nextDueDate, isNull);
  });
}
