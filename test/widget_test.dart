import 'package:flutter_test/flutter_test.dart';

import 'package:grinch/main.dart';

void main() {
  testWidgets('jean luca credit app loads dashboard', (tester) async {
    await tester.pumpWidget(const GrinchApp());

    expect(find.text('JEAN LUCAS CREDIT'), findsOneWidget);
    expect(find.text('Saldo por recuperar'), findsOneWidget);
    expect(find.text('Cobros próximos 30 días'), findsOneWidget);
    expect(find.text('Utilidad pendiente'), findsOneWidget);
    expect(find.text('Préstamos activos'), findsOneWidget);
    expect(find.text('Próximos cobros'), findsOneWidget);
    expect(find.text('Cartera y recuperación'), findsOneWidget);
    expect(find.byTooltip('Cotizador rápido'), findsOneWidget);
    expect(find.byTooltip('Nuevo préstamo'), findsOneWidget);
    expect(find.text('Cotizador rápido'), findsNothing);
    expect(find.text('Nuevo préstamo'), findsNothing);
  });

  testWidgets('loans tab shows premium brand and quick actions', (tester) async {
    await tester.pumpWidget(const GrinchApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Préstamos').last);
    await tester.pumpAndSettle();

    expect(find.text('Jean Lucas Credit'), findsOneWidget);
    expect(find.byTooltip('Cotizador rápido'), findsOneWidget);
    expect(find.byTooltip('Nuevo préstamo'), findsOneWidget);
    expect(find.text('Cotizador rápido'), findsNothing);
    expect(find.text('Nuevo préstamo'), findsNothing);
  });

  testWidgets('analysis tab shows portfolio profitability and quote sections', (tester) async {
    await tester.pumpWidget(const GrinchApp());
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
