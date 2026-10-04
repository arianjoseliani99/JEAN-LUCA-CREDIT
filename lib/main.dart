import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const GrinchApp());
}

class GrinchApp extends StatelessWidget {
  const GrinchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JEAN LUCAS CREDIT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B4A45),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F2EE),
      ),
      home: const HomePage(),
    );
  }
}

enum LoanPaymentFrequency { daily, weekly, monthly, custom }
enum LoanInterestType { fixed, overBalance }
enum LoanStatus { active, finished, overdue }

extension LoanInterestTypeLabel on LoanInterestType {
  String get label {
    switch (this) {
      case LoanInterestType.fixed:
        return 'Fijo';
      case LoanInterestType.overBalance:
        return 'Sobre saldo';
    }
  }
}

extension LoanPaymentFrequencyLabel on LoanPaymentFrequency {
  String get label {
    switch (this) {
      case LoanPaymentFrequency.daily:
        return 'Diario';
      case LoanPaymentFrequency.weekly:
        return 'Semanal';
      case LoanPaymentFrequency.monthly:
        return 'Mensual';
      case LoanPaymentFrequency.custom:
        return 'Cada N días';
    }
  }
}

String _weekdayName(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Lunes';
    case DateTime.tuesday:
      return 'Martes';
    case DateTime.wednesday:
      return 'Miércoles';
    case DateTime.thursday:
      return 'Jueves';
    case DateTime.friday:
      return 'Viernes';
    case DateTime.saturday:
      return 'Sábado';
    case DateTime.sunday:
      return 'Domingo';
    default:
      return 'Día';
  }
}

String _shortDateLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

String _shortMonth(DateTime date) {
  const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
  return months[date.month - 1];
}

String _statusText(LoanRecord loan) {
  switch (loan.status) {
    case LoanStatus.active:
      return 'Activo';
    case LoanStatus.finished:
      return 'Finalizado';
    case LoanStatus.overdue:
      return 'Atrasado';
  }
}

Color _statusColor(LoanRecord loan) {
  switch (loan.status) {
    case LoanStatus.active:
      return const Color(0xFF0E7C61);
    case LoanStatus.finished:
      return const Color(0xFF8B5E00);
    case LoanStatus.overdue:
      return const Color(0xFFB42318);
  }
}

Color _statusBg(LoanRecord loan) {
  switch (loan.status) {
    case LoanStatus.active:
      return const Color(0xFFE8F6EE);
    case LoanStatus.finished:
      return const Color(0xFFFFF3CC);
    case LoanStatus.overdue:
      return const Color(0xFFFFE7E7);
  }
}

class LoanRecord {
  LoanRecord({
    required this.borrowerName,
    required this.amount,
    required this.interestRate,
    required this.months,
    required this.paidMonths,
    this.date,
    this.disbursementDate,
    this.firstPaymentDate,
    this.interestType = LoanInterestType.fixed,
    this.paymentFrequency = LoanPaymentFrequency.monthly,
    this.paymentDayOfMonth,
    this.paymentWeekday,
    this.customEveryDays,
  });

  final String borrowerName;
  final double amount;
  final double interestRate;
  final int months;
  final int paidMonths;
  final DateTime? date;
  final DateTime? disbursementDate;
  final DateTime? firstPaymentDate;
  final LoanInterestType interestType;
  final LoanPaymentFrequency paymentFrequency;
  final int? paymentDayOfMonth;
  final int? paymentWeekday;
  final int? customEveryDays;

  double get totalToReceive => amount + (amount * interestRate / 100);
  double get totalProfit => totalToReceive - amount;
  double get monthlyPayment => months <= 0 ? 0 : totalToReceive / months;
  double get remainingBalance => totalToReceive - (paidMonths * monthlyPayment);
  double get progress => months == 0 ? 0 : (paidMonths / months).clamp(0.0, 1.0);

  bool get isPaidAll => paidMonths >= months;

  LoanStatus get status {
    if (isPaidAll) return LoanStatus.finished;
    if (isOverdue) return LoanStatus.overdue;
    return LoanStatus.active;
  }

  bool get isOverdue {
    if (isPaidAll) return false;
    final installments = buildLoanInstallments(this);
    if (installments.isEmpty) return false;
    final next = installments.firstWhere(
      (item) => !item.isPaid,
      orElse: () => installments.last,
    );
    return next.date.isBefore(DateTime.now());
  }

  DateTime? get nextDueDate {
    if (isPaidAll || months <= 0) return null;
    final installments = buildLoanInstallments(this);
    for (final item in installments) {
      if (!item.isPaid) return item.date;
    }
    return null;
  }

  String get nextDueLabel {
    switch (paymentFrequency) {
      case LoanPaymentFrequency.daily:
        return 'Diario';
      case LoanPaymentFrequency.weekly:
        return _weekdayName(paymentWeekday ?? DateTime.now().weekday);
      case LoanPaymentFrequency.monthly:
        return 'Día ${paymentDayOfMonth ?? 1}';
      case LoanPaymentFrequency.custom:
        return 'Cada ${customEveryDays ?? 1} días';
    }
  }

  LoanRecord copyWith({
    String? borrowerName,
    double? amount,
    double? interestRate,
    int? months,
    int? paidMonths,
    DateTime? date,
    DateTime? disbursementDate,
    DateTime? firstPaymentDate,
    LoanInterestType? interestType,
    LoanPaymentFrequency? paymentFrequency,
    int? paymentDayOfMonth,
    int? paymentWeekday,
    int? customEveryDays,
  }) {
    return LoanRecord(
      borrowerName: borrowerName ?? this.borrowerName,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      months: months ?? this.months,
      paidMonths: paidMonths ?? this.paidMonths,
      date: date ?? this.date,
      disbursementDate: disbursementDate ?? this.disbursementDate,
      firstPaymentDate: firstPaymentDate ?? this.firstPaymentDate,
      interestType: interestType ?? this.interestType,
      paymentFrequency: paymentFrequency ?? this.paymentFrequency,
      paymentDayOfMonth: paymentDayOfMonth ?? this.paymentDayOfMonth,
      paymentWeekday: paymentWeekday ?? this.paymentWeekday,
      customEveryDays: customEveryDays ?? this.customEveryDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'borrowerName': borrowerName,
        'amount': amount,
        'interestRate': interestRate,
        'months': months,
        'paidMonths': paidMonths,
        'date': date?.millisecondsSinceEpoch,
        'disbursementDate': disbursementDate?.millisecondsSinceEpoch,
        'firstPaymentDate': firstPaymentDate?.millisecondsSinceEpoch,
        'interestType': interestType.name,
        'paymentFrequency': paymentFrequency.name,
        'paymentDayOfMonth': paymentDayOfMonth,
        'paymentWeekday': paymentWeekday,
        'customEveryDays': customEveryDays,
      };

  factory LoanRecord.fromJson(Map<String, dynamic> json) {
    final rawFrequency = json['paymentFrequency'] as String?;
    final parsedFrequency = LoanPaymentFrequency.values.firstWhere(
      (freq) => freq.name == rawFrequency,
      orElse: () => LoanPaymentFrequency.monthly,
    );
    final rawInterestType = json['interestType'] as String?;
    final parsedInterestType = LoanInterestType.values.firstWhere(
      (type) => type.name == rawInterestType,
      orElse: () => LoanInterestType.fixed,
    );

    return LoanRecord(
      borrowerName: json['borrowerName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      interestRate: (json['interestRate'] as num?)?.toDouble() ?? 0,
      months: (json['months'] as num?)?.toInt() ?? 0,
      paidMonths: (json['paidMonths'] as num?)?.toInt() ?? 0,
      date: json['date'] != null ? DateTime.fromMillisecondsSinceEpoch(json['date'] as int) : null,
      disbursementDate: json['disbursementDate'] != null ? DateTime.fromMillisecondsSinceEpoch(json['disbursementDate'] as int) : null,
      firstPaymentDate: json['firstPaymentDate'] != null ? DateTime.fromMillisecondsSinceEpoch(json['firstPaymentDate'] as int) : null,
      interestType: parsedInterestType,
      paymentFrequency: parsedFrequency,
      paymentDayOfMonth: json['paymentDayOfMonth'] as int?,
      paymentWeekday: json['paymentWeekday'] as int?,
      customEveryDays: json['customEveryDays'] as int?,
    );
  }
}

class QuoteDraft {
  QuoteDraft({
    required this.borrowerName,
    required this.amount,
    required this.interestRate,
    required this.months,
    this.approved = false,
    this.interestType = LoanInterestType.fixed,
    this.paymentFrequency = LoanPaymentFrequency.monthly,
    this.paymentDayOfMonth,
    this.paymentWeekday,
    this.customEveryDays,
    this.disbursementDate,
    this.firstPaymentDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String borrowerName;
  double amount;
  double interestRate;
  int months;
  bool approved;
  LoanInterestType interestType;
  LoanPaymentFrequency paymentFrequency;
  int? paymentDayOfMonth;
  int? paymentWeekday;
  int? customEveryDays;
  DateTime? disbursementDate;
  DateTime? firstPaymentDate;
  final DateTime createdAt;

  double get totalToReceive => amount + (amount * interestRate / 100);
  double get totalProfit => totalToReceive - amount;
  double get monthlyPayment => totalToReceive / months;

  LoanRecord toLoanRecord() => LoanRecord(
        borrowerName: borrowerName,
        amount: amount,
        interestRate: interestRate,
        months: months,
        paidMonths: 0,
        date: createdAt,
        disbursementDate: disbursementDate,
        firstPaymentDate: firstPaymentDate,
        interestType: interestType,
        paymentFrequency: paymentFrequency,
        paymentDayOfMonth: paymentDayOfMonth,
        paymentWeekday: paymentWeekday,
        customEveryDays: customEveryDays,
      );

  Map<String, dynamic> toJson() => {
        'borrowerName': borrowerName,
        'amount': amount,
        'interestRate': interestRate,
        'months': months,
        'approved': approved,
        'interestType': interestType.name,
        'paymentFrequency': paymentFrequency.name,
        'paymentDayOfMonth': paymentDayOfMonth,
        'paymentWeekday': paymentWeekday,
        'customEveryDays': customEveryDays,
        'disbursementDate': disbursementDate?.millisecondsSinceEpoch,
        'firstPaymentDate': firstPaymentDate?.millisecondsSinceEpoch,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory QuoteDraft.fromJson(Map<String, dynamic> json) {
    final rawFrequency = json['paymentFrequency'] as String?;
    final parsedFrequency = LoanPaymentFrequency.values.firstWhere(
      (freq) => freq.name == rawFrequency,
      orElse: () => LoanPaymentFrequency.monthly,
    );
    final rawInterestType = json['interestType'] as String?;
    final parsedInterestType = LoanInterestType.values.firstWhere(
      (type) => type.name == rawInterestType,
      orElse: () => LoanInterestType.fixed,
    );

    return QuoteDraft(
      borrowerName: json['borrowerName'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      interestRate: (json['interestRate'] as num?)?.toDouble() ?? 0,
      months: (json['months'] as num?)?.toInt() ?? 0,
      approved: json['approved'] as bool? ?? false,
      interestType: parsedInterestType,
      paymentFrequency: parsedFrequency,
      paymentDayOfMonth: json['paymentDayOfMonth'] as int?,
      paymentWeekday: json['paymentWeekday'] as int?,
      customEveryDays: json['customEveryDays'] as int?,
      disbursementDate: json['disbursementDate'] != null ? DateTime.fromMillisecondsSinceEpoch(json['disbursementDate'] as int) : null,
      firstPaymentDate: json['firstPaymentDate'] != null ? DateTime.fromMillisecondsSinceEpoch(json['firstPaymentDate'] as int) : null,
      createdAt: json['createdAt'] != null ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int) : null,
    );
  }
}

class LoanInstallment {
  LoanInstallment({
    required this.number,
    required this.date,
    required this.amount,
    required this.isPaid,
    required this.isNext,
  });

  final int number;
  final DateTime date;
  final double amount;
  final bool isPaid;
  final bool isNext;
}

List<LoanInstallment> buildLoanInstallments(LoanRecord loan) {
  final baseDate = loan.firstPaymentDate ?? loan.disbursementDate ?? DateTime.now();
  final items = <LoanInstallment>[];

  for (var index = 0; index < loan.months; index++) {
    late final DateTime paymentDate;

    switch (loan.paymentFrequency) {
      case LoanPaymentFrequency.daily:
        paymentDate = baseDate.add(Duration(days: index));
        break;
      case LoanPaymentFrequency.weekly:
        var cursor = baseDate;
        if (loan.paymentWeekday != null) {
          while (cursor.weekday != loan.paymentWeekday) {
            cursor = cursor.add(const Duration(days: 1));
          }
        }
        paymentDate = cursor.add(Duration(days: 7 * index));
        break;
      case LoanPaymentFrequency.monthly:
        paymentDate = DateTime(
          baseDate.year,
          baseDate.month + index,
          loan.paymentDayOfMonth ?? baseDate.day,
        );
        break;
      case LoanPaymentFrequency.custom:
        paymentDate = baseDate.add(Duration(days: (loan.customEveryDays ?? 1) * index));
        break;
    }

    items.add(
      LoanInstallment(
        number: index + 1,
        date: paymentDate,
        amount: loan.monthlyPayment,
        isPaid: index < loan.paidMonths,
        isNext: index == loan.paidMonths,
      ),
    );
  }

  return items;
}

String formatCurrency(double value) => 'S/ ${value.toStringAsFixed(2)}';

class PortfolioMetrics {
  PortfolioMetrics(this.loans);

  final List<LoanRecord> loans;

  List<LoanRecord> get active => loans.where((loan) => loan.status == LoanStatus.active).toList();
  List<LoanRecord> get overdue => loans.where((loan) => loan.status == LoanStatus.overdue).toList();
  List<LoanRecord> get finished => loans.where((loan) => loan.status == LoanStatus.finished).toList();

  double get capital => loans.fold(0, (sum, loan) => sum + loan.amount);
  double get outstanding => loans.fold(0, (sum, loan) => sum + loan.remainingBalance);
  double get overdueBalance => overdue.fold(0, (sum, loan) => sum + loan.remainingBalance);
  double get collected => loans.fold(0, (sum, loan) => sum + loan.paidMonths * loan.monthlyPayment);

  double get collectedProfit => loans.fold(0, (sum, loan) {
        if (loan.months <= 0) return sum;
        return sum + loan.totalProfit * loan.paidMonths / loan.months;
      });

  double get remainingProfit => loans.fold(0, (sum, loan) {
        if (loan.months <= 0 || loan.isPaidAll) return sum;
        return sum + loan.totalProfit * (loan.months - loan.paidMonths) / loan.months;
      });

  List<({LoanRecord loan, LoanInstallment installment})> dueBetween(DateTime start, DateTime end) {
    final results = <({LoanRecord loan, LoanInstallment installment})>[];
    for (final loan in loans) {
      for (final installment in buildLoanInstallments(loan)) {
        if (!installment.isPaid &&
            !installment.date.isBefore(start) &&
            installment.date.isBefore(end)) {
          results.add((loan: loan, installment: installment));
        }
      }
    }
    results.sort((a, b) => a.installment.date.compareTo(b.installment.date));
    return results;
  }

  double get next30DaysCollection {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return dueBetween(start, start.add(const Duration(days: 30)))
        .fold(0, (sum, item) => sum + item.installment.amount);
  }

  List<({LoanRecord loan, LoanInstallment installment})> get upcomingInstallments {
    final today = DateTime.now();
    return dueBetween(
      DateTime(today.year, today.month, today.day),
      DateTime(today.year + 5, today.month, today.day),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _loansKey = 'jean_lucas_loans';
  static const String _quotesKey = 'jean_lucas_quotes';

  final List<LoanRecord> _loans = [];
  final List<QuoteDraft> _quoteDrafts = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final loanStrings = prefs.getStringList(_loansKey) ?? <String>[];
    final quoteStrings = prefs.getStringList(_quotesKey) ?? <String>[];

    setState(() {
      _loans
        ..clear()
        ..addAll(loanStrings.map((value) => LoanRecord.fromJson(jsonDecode(value) as Map<String, dynamic>)));
      _quoteDrafts
        ..clear()
        ..addAll(quoteStrings.map((value) => QuoteDraft.fromJson(jsonDecode(value) as Map<String, dynamic>)));
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _loansKey,
      _loans.map((loan) => jsonEncode(loan.toJson())).toList(),
    );
    await prefs.setStringList(
      _quotesKey,
      _quoteDrafts.map((quote) => jsonEncode(quote.toJson())).toList(),
    );
  }

  void _addLoan(LoanRecord loan) {
    setState(() {
      _loans.insert(0, loan);
      _selectedIndex = 0;
    });
    _saveState();
  }

  void _approveQuote(QuoteDraft quote) {
    setState(() {
      quote.approved = true;
      _loans.insert(0, quote.toLoanRecord());
      _quoteDrafts.remove(quote);
    });
    _saveState();
  }

  void _deleteQuote(QuoteDraft quote) {
    setState(() {
      _quoteDrafts.remove(quote);
    });
    _saveState();
  }

  void _updateLoan(LoanRecord original, LoanRecord updated) {
    final index = _loans.indexOf(original);
    if (index < 0) return;
    setState(() => _loans[index] = updated);
    _saveState();
  }

  void _recordPayment(LoanRecord loan) {
    if (loan.isPaidAll) return;
    _updateLoan(loan, loan.copyWith(paidMonths: loan.paidMonths + 1));
  }

  void _openLoanSchedule(LoanRecord loan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LoanScheduleScreen(
          loan: loan,
          onPaymentRecorded: _recordPayment,
        ),
      ),
    );
  }

  void _showEditLoanSheet(LoanRecord loan) {
    final nameController = TextEditingController(text: loan.borrowerName);
    final amountController = TextEditingController(text: loan.amount.toStringAsFixed(2));
    final rateController = TextEditingController(text: loan.interestRate.toStringAsFixed(1));
    final monthsController = TextEditingController(text: loan.months.toString());
    final paidController = TextEditingController(text: loan.paidMonths.toString());
    final dayController = TextEditingController(text: (loan.paymentDayOfMonth ?? 1).toString());
    final customDaysController = TextEditingController(text: (loan.customEveryDays ?? 1).toString());
    DateTime? disbursementDate = loan.disbursementDate;
    DateTime? firstPaymentDate = loan.firstPaymentDate;
    var selectedInterestType = loan.interestType;
    var selectedFrequency = loan.paymentFrequency;
    var selectedWeekday = loan.paymentWeekday ?? DateTime.now().weekday;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setInnerState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Cliente')),
              TextFormField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto'),
              ),
              TextFormField(
                controller: rateController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Interés %'),
              ),
              TextFormField(
                controller: monthsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número de cuotas'),
              ),
              TextFormField(
                controller: paidController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cuotas pagadas'),
              ),
              DropdownButtonFormField<LoanInterestType>(
                initialValue: selectedInterestType,
                decoration: const InputDecoration(labelText: 'Tipo de interés'),
                items: LoanInterestType.values
                    .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setInnerState(() => selectedInterestType = value);
                },
              ),
              DropdownButtonFormField<LoanPaymentFrequency>(
                initialValue: selectedFrequency,
                decoration: const InputDecoration(labelText: 'Frecuencia de pago'),
                items: LoanPaymentFrequency.values
                    .map((frequency) => DropdownMenuItem(value: frequency, child: Text(frequency.label)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setInnerState(() => selectedFrequency = value);
                },
              ),
              if (selectedFrequency == LoanPaymentFrequency.monthly)
                TextFormField(
                  controller: dayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Día del mes'),
                ),
              if (selectedFrequency == LoanPaymentFrequency.weekly)
                DropdownButtonFormField<int>(
                  initialValue: selectedWeekday,
                  decoration: const InputDecoration(labelText: 'Día de la semana'),
                  items: List.generate(
                    7,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(_weekdayName(index + 1)),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) setInnerState(() => selectedWeekday = value);
                  },
                ),
              if (selectedFrequency == LoanPaymentFrequency.custom)
                TextFormField(
                  controller: customDaysController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cada cuántos días'),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: disbursementDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setInnerState(() => disbursementDate = picked);
                },
                icon: const Icon(Icons.calendar_today_rounded),
                label: Text(
                  disbursementDate == null
                      ? 'Fecha de desembolso'
                      : 'Desembolso: ${_shortDateLabel(disbursementDate!)}',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: firstPaymentDate ?? disbursementDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setInnerState(() => firstPaymentDate = picked);
                },
                icon: const Icon(Icons.event_available_rounded),
                label: Text(
                  firstPaymentDate == null
                      ? 'Primera fecha de pago'
                      : 'Primer pago: ${_shortDateLabel(firstPaymentDate!)}',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  final rate = double.tryParse(rateController.text) ?? 0;
                  final months = int.tryParse(monthsController.text) ?? 0;
                  final paid = int.tryParse(paidController.text) ?? 0;
                    final customDays = int.tryParse(customDaysController.text) ?? 1;
                    if (nameController.text.trim().isEmpty || amount <= 0 || months <= 0 ||
                      paid < 0 || paid > months ||
                      (selectedFrequency == LoanPaymentFrequency.custom && customDays <= 0)) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text('Revisa el nombre, monto y número de cuotas.')),
                    );
                    return;
                  }
                  _updateLoan(
                    loan,
                    loan.copyWith(
                      borrowerName: nameController.text.trim(),
                      amount: amount,
                      interestRate: rate,
                      months: months,
                      paidMonths: paid,
                      disbursementDate: disbursementDate,
                      firstPaymentDate: firstPaymentDate,
                      interestType: selectedInterestType,
                      paymentFrequency: selectedFrequency,
                      paymentDayOfMonth: selectedFrequency == LoanPaymentFrequency.monthly
                          ? int.tryParse(dayController.text) ?? 1
                          : null,
                      paymentWeekday: selectedFrequency == LoanPaymentFrequency.weekly ? selectedWeekday : null,
                      customEveryDays: selectedFrequency == LoanPaymentFrequency.custom ? customDays : null,
                    ),
                  );
                  Navigator.pop(sheetContext);
                },
                child: const Text('Guardar cambios'),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickQuoteSheet() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final rateController = TextEditingController(text: '18');
    final monthsController = TextEditingController(text: '6');
    final dayController = TextEditingController(text: '15');
    final customDaysController = TextEditingController(text: '3');
    var selectedInterestType = LoanInterestType.fixed;
    var selectedFrequency = LoanPaymentFrequency.monthly;
    var selectedWeekday = DateTime.now().weekday;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setInnerState) {
          final amount = double.tryParse(amountController.text) ?? 0;
          final rate = double.tryParse(rateController.text) ?? 0;
          final months = int.tryParse(monthsController.text) ?? 0;
          final profit = amount * rate / 100;
          final installment = months > 0 ? (amount + profit) / months : 0.0;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Cotizador rápido', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                    onChanged: (_) => setInnerState(() {}),
                  ),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Monto en soles'),
                    onChanged: (_) => setInnerState(() {}),
                  ),
                  TextFormField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Interés %'),
                    onChanged: (_) => setInnerState(() {}),
                  ),
                  TextFormField(
                    controller: monthsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Número de cuotas'),
                    onChanged: (_) => setInnerState(() {}),
                  ),
                  DropdownButtonFormField<LoanInterestType>(
                    initialValue: selectedInterestType,
                    decoration: const InputDecoration(labelText: 'Tipo de interés'),
                    items: LoanInterestType.values
                        .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setInnerState(() => selectedInterestType = value);
                    },
                  ),
                  DropdownButtonFormField<LoanPaymentFrequency>(
                    initialValue: selectedFrequency,
                    decoration: const InputDecoration(labelText: 'Frecuencia de pago'),
                    items: LoanPaymentFrequency.values
                        .map((frequency) => DropdownMenuItem(value: frequency, child: Text(frequency.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setInnerState(() => selectedFrequency = value);
                    },
                  ),
                  if (selectedFrequency == LoanPaymentFrequency.monthly)
                    TextFormField(
                      controller: dayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Día del mes'),
                    ),
                  if (selectedFrequency == LoanPaymentFrequency.weekly)
                    DropdownButtonFormField<int>(
                      initialValue: selectedWeekday,
                      decoration: const InputDecoration(labelText: 'Día de la semana'),
                      items: List.generate(
                        7,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text(_weekdayName(index + 1)),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) setInnerState(() => selectedWeekday = value);
                      },
                    ),
                  if (selectedFrequency == LoanPaymentFrequency.custom)
                    TextFormField(
                      controller: customDaysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cada cuántos días'),
                    ),
                  const SizedBox(height: 12),
                  _SummaryRow(label: 'Ganancia estimada', value: formatCurrency(profit)),
                  _SummaryRow(label: 'Total a recibir', value: formatCurrency(amount + profit)),
                  _SummaryRow(label: 'Cuota estimada', value: formatCurrency(installment)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty || amount <= 0 || months <= 0) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(content: Text('Completa cliente, monto y cuotas válidas.')),
                          );
                          return;
                        }
                        setState(() {
                          _quoteDrafts.insert(
                            0,
                            QuoteDraft(
                              borrowerName: nameController.text.trim(),
                              amount: amount,
                              interestRate: rate,
                              months: months,
                                interestType: selectedInterestType,
                                paymentFrequency: selectedFrequency,
                                paymentDayOfMonth: selectedFrequency == LoanPaymentFrequency.monthly
                                  ? int.tryParse(dayController.text) ?? 1
                                  : null,
                                paymentWeekday: selectedFrequency == LoanPaymentFrequency.weekly
                                  ? selectedWeekday
                                  : null,
                                customEveryDays: selectedFrequency == LoanPaymentFrequency.custom
                                  ? int.tryParse(customDaysController.text) ?? 1
                                  : null,
                            ),
                          );
                          _selectedIndex = 2;
                        });
                        _saveState();
                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.bookmark_add_rounded),
                      label: const Text('Guardar como borrador'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddLoanSheet() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final rateController = TextEditingController(text: '18');
    final monthsController = TextEditingController(text: '6');
    final dayController = TextEditingController(text: '15');
    final customDaysController = TextEditingController(text: '3');
    DateTime? selectedDate;
    DateTime? firstPaymentDate;
    var selectedInterestType = LoanInterestType.fixed;
    var selectedFrequency = LoanPaymentFrequency.monthly;
    var selectedWeekday = DateTime.now().weekday;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return Container(
              margin: const EdgeInsets.only(top: 40),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Nuevo préstamo',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Cliente'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monto'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: rateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Interés %'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LoanInterestType>(
                      initialValue: selectedInterestType,
                      decoration: const InputDecoration(labelText: 'Tipo de interés'),
                      items: LoanInterestType.values
                          .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setInnerState(() => selectedInterestType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LoanPaymentFrequency>(
                      initialValue: selectedFrequency,
                      decoration: const InputDecoration(labelText: 'Frecuencia de pago'),
                      items: LoanPaymentFrequency.values
                          .map((frequency) => DropdownMenuItem(value: frequency, child: Text(frequency.label)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setInnerState(() => selectedFrequency = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: monthsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Meses'),
                    ),
                    if (selectedFrequency == LoanPaymentFrequency.monthly) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Día del mes'),
                      ),
                    ],
                    if (selectedFrequency == LoanPaymentFrequency.weekly) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedWeekday,
                        decoration: const InputDecoration(labelText: 'Día de la semana'),
                        items: List.generate(
                          7,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text(_weekdayName(index + 1)),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) setInnerState(() => selectedWeekday = value);
                        },
                      ),
                    ],
                    if (selectedFrequency == LoanPaymentFrequency.custom) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: customDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cada cuántos días'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          selectedDate = picked;
                          setInnerState(() {});
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          selectedDate == null ? 'Fecha de desembolso' : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                          style: TextStyle(
                            color: selectedDate == null ? Colors.grey.shade600 : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: firstPaymentDate ?? selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setInnerState(() => firstPaymentDate = picked);
                      },
                      icon: const Icon(Icons.event_available_rounded),
                      label: Text(
                        firstPaymentDate == null
                            ? 'Elegir primera fecha de pago'
                            : 'Primer pago: ${_shortDateLabel(firstPaymentDate!)}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final amount = double.tryParse(amountController.text) ?? 0;
                          final rate = double.tryParse(rateController.text) ?? 0;
                          final months = int.tryParse(monthsController.text) ?? 0;
                            final day = int.tryParse(dayController.text) ?? 1;
                            final customDays = int.tryParse(customDaysController.text) ?? 1;

                            if (nameController.text.trim().isEmpty || amount <= 0 || months <= 0 ||
                              (selectedFrequency == LoanPaymentFrequency.custom && customDays <= 0)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Completa nombre, monto y meses válidos.')),
                            );
                            return;
                          }

                          final loan = LoanRecord(
                            borrowerName: nameController.text.trim(),
                            amount: amount,
                            interestRate: rate,
                            months: months,
                            paidMonths: 0,
                            date: selectedDate ?? DateTime.now(),
                            disbursementDate: selectedDate ?? DateTime.now(),
                            firstPaymentDate: firstPaymentDate ?? selectedDate ?? DateTime.now(),
                            interestType: selectedInterestType,
                            paymentFrequency: selectedFrequency,
                            paymentDayOfMonth: selectedFrequency == LoanPaymentFrequency.monthly ? day : null,
                            paymentWeekday: selectedFrequency == LoanPaymentFrequency.weekly ? selectedWeekday : null,
                            customEveryDays: selectedFrequency == LoanPaymentFrequency.custom ? customDays : null,
                          );

                          _addLoan(loan);
                          Navigator.pop(sheetContext);
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Guardar préstamo'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        loans: _loans,
        onQuickQuote: _showQuickQuoteSheet,
        pendingQuotes: _quoteDrafts.length,
      ),
      LoansScreen(
        loans: _loans,
        onQuickQuote: _showQuickQuoteSheet,
        onEdit: _showEditLoanSheet,
        onLoanTap: _openLoanSchedule,
      ),
      AnalyticsScreen(
        loans: _loans,
        quotes: _quoteDrafts,
        onApprove: _approveQuote,
        onDelete: _deleteQuote,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2EE),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLoanSheet,
        tooltip: 'Nuevo préstamo',
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Préstamos'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_rounded), label: 'Análisis'),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.loans,
    required this.onQuickQuote,
    required this.pendingQuotes,
  });

  final List<LoanRecord> loans;
  final VoidCallback onQuickQuote;
  final int pendingQuotes;

  @override
  Widget build(BuildContext context) {
    final metrics = PortfolioMetrics(loans);
    final totalExpected = loans.fold<double>(0, (sum, loan) => sum + loan.totalToReceive);
    final recoveryProgress = totalExpected == 0 ? 0.0 : (metrics.collected / totalExpected).clamp(0.0, 1.0);
    final upcoming = metrics.upcomingInstallments.take(5).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'JEAN LUCAS CREDIT',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Panel de cartera • ${_shortDateLabel(DateTime.now())}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onQuickQuote,
                  tooltip: 'Cotizador rápido',
                  icon: const Icon(Icons.calculate_outlined, size: 21),
                ),
                CircleAvatar(
                  backgroundColor: const Color(0xFF0B4A45),
                  child: Text('${loans.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Saldo por recuperar',
                    value: formatCurrency(metrics.outstanding),
                    accent: const Color(0xFF0B4A45),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Cobros próximos 30 días',
                    value: formatCurrency(metrics.next30DaysCollection),
                    accent: const Color(0xFFB77A00),
                    icon: Icons.event_available_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'En mora',
                    value: formatCurrency(metrics.overdueBalance),
                    accent: const Color(0xFFB42318),
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Utilidad pendiente',
                    value: formatCurrency(metrics.remainingProfit),
                    accent: const Color(0xFF1E5F74),
                    icon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cartera y recuperación',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(label: 'Capital colocado', value: formatCurrency(metrics.capital)),
                  _SummaryRow(label: 'Recaudado', value: formatCurrency(metrics.collected)),
                  _SummaryRow(label: 'Utilidad ya generada', value: formatCurrency(metrics.collectedProfit)),
                  _SummaryRow(label: 'Préstamos activos', value: '${metrics.active.length}'),
                  _SummaryRow(label: 'Préstamos atrasados', value: '${metrics.overdue.length}'),
                  _SummaryRow(label: 'Préstamos liquidados', value: '${metrics.finished.length}'),
                  _SummaryRow(label: 'Borradores', value: '$pendingQuotes'),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Recuperación del total programado', style: TextStyle(fontSize: 12)),
                      ),
                      Text('${(recoveryProgress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: recoveryProgress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE7EAEE),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0E7C61)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionTitle(label: 'Próximos cobros', count: upcoming.length, color: const Color(0xFF0B4A45)),
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              _EmptyPanel(
                message: loans.isEmpty
                    ? 'Registra un préstamo para ver aquí sus vencimientos.'
                    : 'No hay cuotas pendientes dentro del calendario próximo.',
                icon: Icons.event_note_rounded,
              )
            else
              ...upcoming.map((entry) {
                final late = entry.loan.status == LoanStatus.overdue;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Icon(
                        late ? Icons.warning_amber_rounded : Icons.event_rounded,
                        color: late ? const Color(0xFFB42318) : const Color(0xFF0E7C61),
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.loan.borrowerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              'Cuota ${entry.installment.number} • ${_shortDateLabel(entry.installment.date)}${late ? ' • Atrasado' : ''}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      Text(formatCurrency(entry.installment.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                );
              }),
            if (loans.isEmpty) ...[
              const SizedBox(height: 12),
              _EmptyPanel(message: 'Aún no hay préstamos registrados.', icon: Icons.receipt_long_rounded),
            ],
          ],
        ),
      ),
    );
  }
}

class LoansScreen extends StatelessWidget {
  const LoansScreen({
    super.key,
    required this.loans,
    required this.onQuickQuote,
    required this.onEdit,
    required this.onLoanTap,
  });

  final List<LoanRecord> loans;
  final VoidCallback onQuickQuote;
  final void Function(LoanRecord loan) onEdit;
  final void Function(LoanRecord loan) onLoanTap;

  @override
  Widget build(BuildContext context) {
    final active = loans.where((loan) => loan.status == LoanStatus.active).toList();
    final overdue = loans.where((loan) => loan.status == LoanStatus.overdue).toList();
    final finished = loans.where((loan) => loan.status == LoanStatus.finished).toList();
    final activeBalance = active.fold<double>(0, (sum, loan) => sum + loan.remainingBalance);
    final overdueBalance = overdue.fold<double>(0, (sum, loan) => sum + loan.remainingBalance);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Jean Lucas Credit',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF101827),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onQuickQuote,
                  tooltip: 'Cotizador rápido',
                  icon: const Icon(Icons.calculate_outlined, size: 21),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PortfolioCard(
                    label: 'POR COBRAR',
                    value: formatCurrency(activeBalance),
                    detail: '${active.length} préstamos al día',
                    color: const Color(0xFF0E7C61),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PortfolioCard(
                    label: 'EN RIESGO',
                    value: formatCurrency(overdueBalance),
                    detail: '${overdue.length} préstamos en mora',
                    color: const Color(0xFFB42318),
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (active.isNotEmpty) ...[
              _SectionTitle(
                label: 'Préstamos activos',
                count: active.length,
                color: const Color(0xFF1E8E5A),
              ),
              const SizedBox(height: 10),
              ...active.map(
                (loan) => _LoanCard(loan: loan, onEdit: onEdit, onTap: onLoanTap),
              ),
            ],
            if (overdue.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionTitle(
                label: 'En mora',
                count: overdue.length,
                color: const Color(0xFFB42318),
              ),
              const SizedBox(height: 10),
              ...overdue.map(
                (loan) => _LoanCard(loan: loan, onEdit: onEdit, onTap: onLoanTap),
              ),
            ],
            if (finished.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionTitle(
                label: 'Préstamos liquidados',
                count: finished.length,
                color: const Color(0xFF8B5E00),
              ),
              const SizedBox(height: 10),
              ...finished.map(
                (loan) => _LoanCard(loan: loan, onEdit: onEdit, onTap: onLoanTap),
              ),
            ],
            if (loans.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 32, color: Color(0xFF0B4A45)),
                    SizedBox(height: 10),
                    Text('Aún no hay préstamos registrados.'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({
    super.key,
    required this.loans,
    required this.quotes,
    required this.onApprove,
    required this.onDelete,
  });

  final List<LoanRecord> loans;
  final List<QuoteDraft> quotes;
  final void Function(QuoteDraft quote) onApprove;
  final void Function(QuoteDraft quote) onDelete;

  @override
  Widget build(BuildContext context) {
    final metrics = PortfolioMetrics(loans);
    final maximumProfit = loans.fold<double>(
      0,
      (maximum, loan) => loan.totalProfit > maximum ? loan.totalProfit : maximum,
    );
    final openCapital = [...metrics.active, ...metrics.overdue]
        .fold<double>(0, (sum, loan) => sum + loan.amount);
    final margin = openCapital == 0 ? 0.0 : (metrics.remainingProfit / openCapital) * 100;
    final upcoming = metrics.upcomingInstallments.take(6).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Análisis de cartera',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text('Rentabilidad, recuperación y calendario de cobros', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E5F74),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('UTILIDAD PENDIENTE ESTIMADA', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(formatCurrency(metrics.remainingProfit), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                  Text('Margen pendiente: ${margin.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Capital colocado',
                    value: formatCurrency(metrics.capital),
                    accent: const Color(0xFF0B4A45),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Saldo pendiente',
                    value: formatCurrency(metrics.outstanding),
                    accent: const Color(0xFFB77A00),
                    icon: Icons.pending_actions_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Recaudado',
                    value: formatCurrency(metrics.collected),
                    accent: const Color(0xFF1E8E5A),
                    icon: Icons.savings_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Utilidad generada',
                    value: formatCurrency(metrics.collectedProfit),
                    accent: const Color(0xFF1E5F74),
                    icon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionTitle(label: 'Estado de la cartera', count: loans.length, color: const Color(0xFF0B4A45)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _SummaryRow(label: 'Al día', value: '${metrics.active.length} préstamos'),
                  _SummaryRow(label: 'En mora', value: '${metrics.overdue.length} préstamos • ${formatCurrency(metrics.overdueBalance)}'),
                  _SummaryRow(label: 'Liquidados', value: '${metrics.finished.length} préstamos'),
                  _SummaryRow(label: 'Cotizaciones guardadas', value: '${quotes.length}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionTitle(label: 'Rentabilidad por préstamo', count: loans.length, color: const Color(0xFF1E5F74)),
            const SizedBox(height: 8),
            if (loans.isEmpty)
              _EmptyPanel(message: 'Cuando registres préstamos, verás aquí su utilidad calculada.', icon: Icons.bar_chart_rounded)
            else
              ...loans.map(
                (loan) {
                  final ratio = maximumProfit <= 0 ? 0.0 : (loan.totalProfit / maximumProfit).clamp(0.0, 1.0);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(loan.borrowerName, style: const TextStyle(fontWeight: FontWeight.w700))),
                            Text(formatCurrency(loan.totalProfit), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFE7EAEE),
                                  valueColor: AlwaysStoppedAnimation<Color>(_statusColor(loan)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${loan.interestRate.toStringAsFixed(1)}% • ${_statusText(loan)}', style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 18),
            _SectionTitle(label: 'Cobros en los próximos 30 días', count: upcoming.length, color: const Color(0xFFB77A00)),
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              _EmptyPanel(message: 'No hay cuotas programadas en este periodo.', icon: Icons.event_note_rounded)
            else
              ...upcoming.map(
                (entry) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  title: Text(entry.loan.borrowerName),
                  subtitle: Text('Cuota ${entry.installment.number} • ${_shortDateLabel(entry.installment.date)}'),
                  trailing: Text(formatCurrency(entry.installment.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            const SizedBox(height: 18),
            _SectionTitle(label: 'Cotizaciones en borrador', count: quotes.length, color: const Color(0xFF1E5F74)),
            const SizedBox(height: 8),
            if (quotes.isEmpty)
              _EmptyPanel(message: 'No hay cotizaciones guardadas.', icon: Icons.request_quote_rounded)
            else
              ...quotes.map(
                (quote) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              quote.borrowerName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: quote.approved ? const Color(0xFF2E8B57) : const Color(0xFF7A7A7A),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              quote.approved ? 'Aprobada' : 'Borrador',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(label: 'Monto', value: formatCurrency(quote.amount)),
                      _SummaryRow(label: 'Interés', value: '${quote.interestRate.toStringAsFixed(1)}%'),
                      _SummaryRow(label: 'Meses', value: '${quote.months}'),
                      _SummaryRow(label: 'Margen', value: formatCurrency(quote.totalProfit)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => onApprove(quote),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(quote.approved ? 'Aprobado' : 'Aprobar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () => onDelete(quote),
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: const Color(0xFFB94A48),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0B4A45), size: 21),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: Colors.grey.shade700, fontSize: 12))),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5C6771), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 5),
          Text(detail, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan, required this.onEdit, required this.onTap});

  final LoanRecord loan;
  final void Function(LoanRecord loan) onEdit;
  final void Function(LoanRecord loan) onTap;

  @override
  Widget build(BuildContext context) {
    final due = loan.nextDueDate;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: () => onTap(loan),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loan.borrowerName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusBg(loan),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusText(loan),
                      style: TextStyle(color: _statusColor(loan), fontWeight: FontWeight.w700, fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    onPressed: () => onEdit(loan),
                    tooltip: 'Editar préstamo',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFE9EDF1),
                      foregroundColor: const Color(0xFF1A1E25),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 15),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cuota ${loan.isPaidAll ? loan.months : loan.paidMonths + 1} de ${loan.months}',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ),
                  Text(formatCurrency(loan.remainingBalance), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ],
              ),
              if (due != null) ...[
                const SizedBox(height: 5),
                Text(
                  'Próximo vencimiento: ${due.day} ${_shortMonth(due)}',
                  style: TextStyle(
                    color: loan.status == LoanStatus.overdue ? _statusColor(loan) : const Color(0xFF8B5E00),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: loan.progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(_statusColor(loan)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoanScheduleScreen extends StatefulWidget {
  const LoanScheduleScreen({
    super.key,
    required this.loan,
    required this.onPaymentRecorded,
  });

  final LoanRecord loan;
  final void Function(LoanRecord loan) onPaymentRecorded;

  @override
  State<LoanScheduleScreen> createState() => _LoanScheduleScreenState();
}

class _LoanScheduleScreenState extends State<LoanScheduleScreen> {
  late LoanRecord _loan = widget.loan;

  Future<void> _recordNextPayment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar pago'),
        content: Text('¿Confirmas el pago de ${formatCurrency(_loan.monthlyPayment)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final updatedLoan = _loan.copyWith(paidMonths: _loan.paidMonths + 1);
    widget.onPaymentRecorded(_loan);
    setState(() => _loan = updatedLoan);
  }

  @override
  Widget build(BuildContext context) {
    final installments = buildLoanInstallments(_loan);
    return Scaffold(
      appBar: AppBar(title: const Text('Cronograma de pagos')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(_loan.borrowerName, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Monto total a recibir', value: formatCurrency(_loan.totalToReceive)),
          _SummaryRow(label: 'Saldo pendiente', value: formatCurrency(_loan.remainingBalance)),
          _SummaryRow(label: 'Frecuencia', value: _loan.nextDueLabel),
          if (!_loan.isPaidAll) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _recordNextPayment,
                icon: const Icon(Icons.payments_rounded),
                label: const Text('Registrar siguiente cuota'),
              ),
              ),
          ],
          const SizedBox(height: 22),
          const Text('Cuotas programadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...installments.map(
            (installment) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: installment.isPaid ? const Color(0xFFE8F6EE) : const Color(0xFFE9EDF1),
                child: Icon(
                  installment.isPaid ? Icons.check_rounded : Icons.event_rounded,
                  color: installment.isPaid ? const Color(0xFF0E7C61) : const Color(0xFF45515D),
                  size: 18,
                ),
              ),
              title: Text('Cuota ${installment.number}'),
              subtitle: Text('${installment.date.day}/${installment.date.month}/${installment.date.year}'),
              trailing: Text(
                installment.isPaid ? 'Pagada' : formatCurrency(installment.amount),
                style: TextStyle(
                  color: installment.isPaid ? const Color(0xFF0E7C61) : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
