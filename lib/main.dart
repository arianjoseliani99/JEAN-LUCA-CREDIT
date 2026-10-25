import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'local_pin_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GrinchApp());
}

const _appearancePalettes = <({String name, Color color})>[
  (name: 'Turquesa', color: Color(0xFF08A99A)),
  (name: 'Azul', color: Color(0xFF3478F6)),
  (name: 'Morado', color: Color(0xFF7755C9)),
  (name: 'Verde', color: Color(0xFF248A5A)),
  (name: 'Naranja', color: Color(0xFFD97706)),
];

const _textScaleValues = <double>[0.9, 1.0, 1.12];
const _textScaleLabels = <String>['Pequeño', 'Mediano', 'Grande'];

class GrinchApp extends StatefulWidget {
  const GrinchApp({super.key});

  @override
  State<GrinchApp> createState() => _GrinchAppState();
}

class _GrinchAppState extends State<GrinchApp> {
  static const _darkModeKey = 'jean_lucas_dark_mode';
  static const _themeColorKey = 'jean_lucas_theme_color';
  static const _textScaleKey = 'jean_lucas_text_scale';

  bool _darkMode = false;
  int _themeColorIndex = 0;
  int _textScaleIndex = 1;
  bool _loadingAppearance = true;
  String? _appearanceError;

  @override
  void initState() {
    super.initState();
    _loadAppearance();
  }

  Future<void> _loadAppearance() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _darkMode = preferences.getBool(_darkModeKey) ?? false;
        _themeColorIndex = (preferences.getInt(_themeColorKey) ?? 0).clamp(
          0,
          _appearancePalettes.length - 1,
        );
        _textScaleIndex = (preferences.getInt(_textScaleKey) ?? 1).clamp(
          0,
          _textScaleValues.length - 1,
        );
        _loadingAppearance = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _appearanceError = 'No se pudo cargar la apariencia guardada: $error';
        _loadingAppearance = false;
      });
    }
  }

  Future<bool> _saveAppearance({
    bool? darkMode,
    int? themeColorIndex,
    int? textScaleIndex,
  }) async {
    final previousDarkMode = _darkMode;
    final previousThemeColorIndex = _themeColorIndex;
    final previousTextScaleIndex = _textScaleIndex;

    setState(() {
      if (darkMode != null) _darkMode = darkMode;
      if (themeColorIndex != null) _themeColorIndex = themeColorIndex;
      if (textScaleIndex != null) _textScaleIndex = textScaleIndex;
    });

    try {
      final preferences = await SharedPreferences.getInstance();
      if (darkMode != null &&
          !await preferences.setBool(_darkModeKey, darkMode)) {
        throw StateError('El dispositivo no confirmó el guardado del modo.');
      }
      if (themeColorIndex != null &&
          !await preferences.setInt(_themeColorKey, themeColorIndex)) {
        throw StateError('El dispositivo no confirmó el guardado del color.');
      }
      if (textScaleIndex != null &&
          !await preferences.setInt(_textScaleKey, textScaleIndex)) {
        throw StateError('El dispositivo no confirmó el guardado del tamaño.');
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _darkMode = previousDarkMode;
          _themeColorIndex = previousThemeColorIndex;
          _textScaleIndex = previousTextScaleIndex;
        });
      }
      debugPrint('No se pudo guardar la apariencia: $error');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final seedColor = _appearancePalettes[_themeColorIndex].color;
    return MaterialApp(
      title: 'JEAN LUCAS CREDIT',
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(seedColor, Brightness.light),
      darkTheme: _buildAppTheme(seedColor, Brightness.dark),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(_textScaleValues[_textScaleIndex]),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _loadingAppearance
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _appearanceError != null
          ? Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_appearanceError!, textAlign: TextAlign.center),
                  ),
                ),
              ),
            )
          : LocalPinGate(
              child: HomePage(
                darkMode: _darkMode,
                themeColorIndex: _themeColorIndex,
                textScaleIndex: _textScaleIndex,
                onDarkModeChanged: (value) => _saveAppearance(darkMode: value),
                onThemeColorChanged: (value) =>
                    _saveAppearance(themeColorIndex: value),
                onTextScaleChanged: (value) =>
                    _saveAppearance(textScaleIndex: value),
              ),
            ),
    );
  }
}

ThemeData _buildAppTheme(Color seedColor, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ).copyWith(
        surface: isDark ? const Color(0xFF101820) : const Color(0xFFF3F7FA),
        onSurface: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF142337),
      );
  final borderColor = isDark
      ? const Color(0xFF34434E)
      : const Color(0xFFE5EDF4);

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme:
        (isDark
                ? Typography.material2021().white
                : Typography.material2021().black)
            .apply(
              fontFamily: 'Roboto',
              bodyColor: scheme.onSurface,
              displayColor: scheme.onSurface,
            ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    iconTheme: IconThemeData(color: scheme.primary, size: 22),
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF19252F) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1B2832) : const Color(0xFFF7FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 8,
    ),
  );
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
  const months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
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
      return const Color(0xFF0A9C89);
    case LoanStatus.finished:
      return const Color(0xFF8B5E00);
    case LoanStatus.overdue:
      return const Color(0xFFB42318);
  }
}

Color _statusBg(BuildContext context, LoanRecord loan) {
  if (Theme.of(context).brightness == Brightness.dark) {
    return _statusColor(loan).withValues(alpha: 0.2);
  }
  switch (loan.status) {
    case LoanStatus.active:
      return const Color(0xFFE2F7F3);
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
  double get progress =>
      months == 0 ? 0 : (paidMonths / months).clamp(0.0, 1.0);

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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(next.date.year, next.date.month, next.date.day);
    return dueDay.isBefore(today);
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
      date: json['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['date'] as int)
          : null,
      disbursementDate: json['disbursementDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['disbursementDate'] as int)
          : null,
      firstPaymentDate: json['firstPaymentDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['firstPaymentDate'] as int)
          : null,
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
      disbursementDate: json['disbursementDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['disbursementDate'] as int)
          : null,
      firstPaymentDate: json['firstPaymentDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['firstPaymentDate'] as int)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
          : null,
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
  final baseDate =
      loan.firstPaymentDate ?? loan.disbursementDate ?? DateTime.now();
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
        paymentDate = baseDate.add(
          Duration(days: (loan.customEveryDays ?? 1) * index),
        );
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

  List<LoanRecord> get active =>
      loans.where((loan) => loan.status == LoanStatus.active).toList();
  List<LoanRecord> get overdue =>
      loans.where((loan) => loan.status == LoanStatus.overdue).toList();
  List<LoanRecord> get finished =>
      loans.where((loan) => loan.status == LoanStatus.finished).toList();

  double get capital => loans.fold(0, (sum, loan) => sum + loan.amount);
  double get outstanding =>
      loans.fold(0, (sum, loan) => sum + loan.remainingBalance);
  List<({LoanRecord loan, LoanInstallment installment})>
  get overdueInstallments {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final results = <({LoanRecord loan, LoanInstallment installment})>[];
    for (final loan in loans) {
      for (final installment in buildLoanInstallments(loan)) {
        final dueDay = DateTime(
          installment.date.year,
          installment.date.month,
          installment.date.day,
        );
        if (!installment.isPaid && dueDay.isBefore(today)) {
          results.add((loan: loan, installment: installment));
        }
      }
    }
    results.sort((a, b) => a.installment.date.compareTo(b.installment.date));
    return results;
  }

  double get overdueBalance =>
      overdueInstallments.fold(0, (sum, item) => sum + item.installment.amount);
  double get collected =>
      loans.fold(0, (sum, loan) => sum + loan.paidMonths * loan.monthlyPayment);

  double get collectedProfit => loans.fold(0, (sum, loan) {
    if (loan.months <= 0) return sum;
    return sum + loan.totalProfit * loan.paidMonths / loan.months;
  });

  double get remainingProfit => loans.fold(0, (sum, loan) {
    if (loan.months <= 0 || loan.isPaidAll) return sum;
    return sum +
        loan.totalProfit * (loan.months - loan.paidMonths) / loan.months;
  });

  List<({LoanRecord loan, LoanInstallment installment})> dueBetween(
    DateTime start,
    DateTime end,
  ) {
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
    return dueBetween(
      start,
      start.add(const Duration(days: 30)),
    ).fold(0, (sum, item) => sum + item.installment.amount);
  }

  List<({LoanRecord loan, LoanInstallment installment})>
  get upcomingInstallments {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return dueBetween(start, start.add(const Duration(days: 30)));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.darkMode = false,
    this.themeColorIndex = 0,
    this.textScaleIndex = 1,
    this.onDarkModeChanged,
    this.onThemeColorChanged,
    this.onTextScaleChanged,
  });

  final bool darkMode;
  final int themeColorIndex;
  final int textScaleIndex;
  final Future<bool> Function(bool value)? onDarkModeChanged;
  final Future<bool> Function(int value)? onThemeColorChanged;
  final Future<bool> Function(int value)? onTextScaleChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const String _loansKey = 'jean_lucas_loans';
  static const String _quotesKey = 'jean_lucas_quotes';
  static const String _notificationsKey = 'jean_lucas_notifications_enabled';
  static const String _reminderDaysKey = 'jean_lucas_reminder_days';
  static const String _reminderHourKey = 'jean_lucas_reminder_hour';
  static const String _reminderMinuteKey = 'jean_lucas_reminder_minute';
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  final List<LoanRecord> _loans = [];
  final List<QuoteDraft> _quoteDrafts = [];
  Future<void> _saveQueue = Future<void>.value();
  int _localChangeVersion = 0;
  int _selectedIndex = 0;
  bool _notificationsEnabled = false;
  int _reminderDaysBefore = 1;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _notificationPluginReady = false;
  bool _androidExactAlarmsAllowed = false;
  bool _isLoadingState = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached) &&
        !_isLoadingState) {
      unawaited(_persistPortfolioSnapshot());
    }
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    var loanStrings = prefs.getStringList(_loansKey) ?? <String>[];
    var quoteStrings = prefs.getStringList(_quotesKey) ?? <String>[];
    final notificationsEnabled = prefs.getBool(_notificationsKey) ?? false;
    final reminderDaysBefore = prefs.getInt(_reminderDaysKey) ?? 1;
    final reminderHour = prefs.getInt(_reminderHourKey) ?? 9;
    final reminderMinute = prefs.getInt(_reminderMinuteKey) ?? 0;
    // Do not replace a state the user changed while preferences were loading.
    if (_localChangeVersion != 0) {
      if (mounted) setState(() => _isLoadingState = false);
      return;
    }

    setState(() {
      _loans
        ..clear()
        ..addAll(
          loanStrings.map(
            (value) =>
                LoanRecord.fromJson(jsonDecode(value) as Map<String, dynamic>),
          ),
        );
      _quoteDrafts
        ..clear()
        ..addAll(
          quoteStrings.map(
            (value) =>
                QuoteDraft.fromJson(jsonDecode(value) as Map<String, dynamic>),
          ),
        );
      _notificationsEnabled = notificationsEnabled;
      _reminderDaysBefore = reminderDaysBefore.clamp(0, 30).toInt();
      _reminderTime = TimeOfDay(
        hour: reminderHour.clamp(0, 23).toInt(),
        minute: reminderMinute.clamp(0, 59).toInt(),
      );
      _isLoadingState = false;
    });

    if (!_notificationsEnabled ||
        kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      return;
    }

    try {
      await _initializeNotificationPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        _androidExactAlarmsAllowed =
            await _notifications
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.canScheduleExactNotifications() ??
            false;
      }
      await _scheduleLoanReminders();
    } catch (_) {
      // Notification setup can fail independently of loading the saved portfolio.
    }
  }

  Future<bool> _requestNotificationPermission() async {
    bool granted = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      granted =
          await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      granted =
          await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      granted =
          await _notifications
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }

    return granted;
  }

  Future<void> _initializeNotificationPlugin() async {
    if (_notificationPluginReady) return;
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // Keep the timezone package's local default when the native lookup is unavailable.
    }

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );
    _notificationPluginReady = true;
  }

  Future<bool> _saveNotificationSettings(
    bool enabled,
    int daysBefore,
    TimeOfDay time,
  ) async {
    if (enabled) {
      if (kIsWeb ||
          !{
            TargetPlatform.android,
            TargetPlatform.iOS,
            TargetPlatform.macOS,
          }.contains(defaultTargetPlatform)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Los recordatorios están disponibles en Android, iOS y macOS.',
              ),
            ),
          );
        }
        return false;
      }
      try {
        await _initializeNotificationPlugin();
        final granted = await _requestNotificationPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Permite las notificaciones en tu dispositivo para activar los recordatorios.',
                ),
              ),
            );
          }
          return false;
        }
        if (defaultTargetPlatform == TargetPlatform.android) {
          final androidNotifications = _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
          _androidExactAlarmsAllowed =
              await androidNotifications?.canScheduleExactNotifications() ??
              false;
          if (!_androidExactAlarmsAllowed) {
            _androidExactAlarmsAllowed =
                await androidNotifications?.requestExactAlarmsPermission() ??
                false;
          }
          if (!_androidExactAlarmsAllowed) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Habilita “Alarmas y recordatorios” para que el aviso llegue a la hora elegida.',
                  ),
                ),
              );
            }
            return false;
          }
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo configurar el permiso de notificaciones en este dispositivo.',
              ),
            ),
          );
        }
        return false;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
    await prefs.setInt(_reminderDaysKey, daysBefore);
    await prefs.setInt(_reminderHourKey, time.hour);
    await prefs.setInt(_reminderMinuteKey, time.minute);
    if (!mounted) return false;
    setState(() {
      _notificationsEnabled = enabled;
      _reminderDaysBefore = daysBefore;
      _reminderTime = time;
    });

    if (enabled) {
      try {
        final count = await _scheduleLoanReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                count == 0
                    ? 'No hay cuotas pendientes con fecha futura para recordar.'
                    : 'Se programaron $count recordatorio(s) de pago.',
              ),
            ),
          );
        }
      } catch (_) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_notificationsKey, false);
        if (mounted) {
          setState(() => _notificationsEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudieron programar los recordatorios.'),
            ),
          );
        }
        return false;
      }
    } else if (_notificationPluginReady) {
      await _notifications.cancelAll();
    }
    return true;
  }

  Future<int> _scheduleLoanReminders() async {
    if (!_notificationPluginReady || !_notificationsEnabled) return 0;
    await _notifications.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    final scheduled =
        <
          ({LoanRecord loan, LoanInstallment installment, tz.TZDateTime time})
        >[];
    for (final loan in _loans) {
      for (final installment in buildLoanInstallments(loan)) {
        if (installment.isPaid) continue;
        final reminderDate = installment.date.subtract(
          Duration(days: _reminderDaysBefore),
        );
        final reminderTime = tz.TZDateTime(
          tz.local,
          reminderDate.year,
          reminderDate.month,
          reminderDate.day,
          _reminderTime.hour,
          _reminderTime.minute,
        );
        if (reminderTime.isAfter(now)) {
          scheduled.add((
            loan: loan,
            installment: installment,
            time: reminderTime,
          ));
        } else if (reminderDate.year == now.year &&
            reminderDate.month == now.month &&
            reminderDate.day == now.day) {
          scheduled.add((
            loan: loan,
            installment: installment,
            time: now.add(const Duration(seconds: 5)),
          ));
        }
      }
    }
    scheduled.sort((a, b) => a.time.compareTo(b.time));
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'loan_payment_reminders',
        'Recordatorios de pago',
        channelDescription: 'Avisos antes de las fechas de pago de préstamos',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
    for (var index = 0; index < scheduled.length && index < 64; index++) {
      final reminder = scheduled[index];
      await _notifications.zonedSchedule(
        id: 10000 + index,
        title: 'Recordatorio de pago',
        body:
            '${reminder.loan.borrowerName}: ${formatCurrency(reminder.installment.amount)}',
        scheduledDate: reminder.time,
        notificationDetails: details,
        androidScheduleMode: _androidExactAlarmsAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.loan.borrowerName,
      );
    }
    return scheduled.length < 64 ? scheduled.length : 64;
  }

  Future<void> _showTestNotification() async {
    try {
      await _initializeNotificationPlugin();
      await _notifications.show(
        id: 9999,
        title: 'Jean Lucas Credit',
        body: 'Las notificaciones están activas en este dispositivo.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'loan_payment_reminders',
            'Recordatorios de pago',
            channelDescription:
                'Avisos antes de las fechas de pago de préstamos',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo mostrar la notificación de prueba. Revisa los permisos del teléfono.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveState() async {
    // Take the snapshot before any async work, then commit snapshots in order.
    final loanSnapshot = _loans
        .map((loan) => jsonEncode(loan.toJson()))
        .toList();
    final quoteSnapshot = _quoteDrafts
        .map((quote) => jsonEncode(quote.toJson()))
        .toList();
    await _persistPortfolioSnapshot(loanSnapshot, quoteSnapshot);
    if (_notificationsEnabled) {
      try {
        await _scheduleLoanReminders();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudieron actualizar los recordatorios.'),
            ),
          );
        }
      }
    }
  }

  Future<void> _persistPortfolioSnapshot([
    List<String>? loanSnapshot,
    List<String>? quoteSnapshot,
  ]) async {
    final loansToSave =
        loanSnapshot ??
        _loans.map((loan) => jsonEncode(loan.toJson())).toList();
    final quotesToSave =
        quoteSnapshot ??
        _quoteDrafts.map((quote) => jsonEncode(quote.toJson())).toList();
    Future<void> writeSnapshot() async {
      final prefs = await SharedPreferences.getInstance();
      final loansSaved = await prefs.setStringList(_loansKey, loansToSave);
      final quotesSaved = await prefs.setStringList(_quotesKey, quotesToSave);
      if (!loansSaved || !quotesSaved) {
        throw StateError(
          'El dispositivo no confirmó el guardado de la cartera.',
        );
      }
    }

    _saveQueue = _saveQueue.then(
      (_) => writeSnapshot(),
      onError: (Object _, StackTrace _) => writeSnapshot(),
    );
    try {
      await _saveQueue;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudieron guardar los cambios en este dispositivo.',
            ),
          ),
        );
      }
    }
  }

  void _addLoan(LoanRecord loan) {
    setState(() {
      _localChangeVersion++;
      _loans.insert(0, loan);
      _selectedIndex = 0;
    });
    _saveState();
  }

  void _approveQuote(QuoteDraft quote) {
    setState(() {
      _localChangeVersion++;
      quote.approved = true;
      _loans.insert(0, quote.toLoanRecord());
      _quoteDrafts.remove(quote);
    });
    _saveState();
  }

  void _deleteQuote(QuoteDraft quote) {
    setState(() {
      _localChangeVersion++;
      _quoteDrafts.remove(quote);
    });
    _saveState();
  }

  void _updateLoan(LoanRecord original, LoanRecord updated) {
    final index = _loans.indexOf(original);
    if (index < 0) return;
    setState(() {
      _localChangeVersion++;
      _loans[index] = updated;
    });
    _saveState();
  }

  void _deleteLoan(LoanRecord loan) {
    setState(() {
      _localChangeVersion++;
      _loans.remove(loan);
    });
    _saveState();
  }

  void _recordPayment(LoanRecord loan) {
    if (loan.isPaidAll) return;
    _updateLoan(loan, loan.copyWith(paidMonths: loan.paidMonths + 1));
  }

  void _openLoanSchedule(LoanRecord loan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            LoanScheduleScreen(loan: loan, onPaymentRecorded: _recordPayment),
      ),
    );
  }

  void _showEditLoanSheet(LoanRecord loan) {
    final nameController = TextEditingController(text: loan.borrowerName);
    final amountController = TextEditingController(
      text: loan.amount.toStringAsFixed(2),
    );
    final rateController = TextEditingController(
      text: loan.interestRate.toStringAsFixed(1),
    );
    final monthsController = TextEditingController(
      text: loan.months.toString(),
    );
    final paidController = TextEditingController(
      text: loan.paidMonths.toString(),
    );
    final dayController = TextEditingController(
      text: (loan.paymentDayOfMonth ?? 1).toString(),
    );
    final customDaysController = TextEditingController(
      text: (loan.customEveryDays ?? 1).toString(),
    );
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
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                ),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Monto'),
                ),
                TextFormField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Interés %'),
                ),
                TextFormField(
                  controller: monthsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Número de cuotas',
                  ),
                ),
                TextFormField(
                  controller: paidController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cuotas pagadas',
                  ),
                ),
                DropdownButtonFormField<LoanInterestType>(
                  initialValue: selectedInterestType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de interés',
                  ),
                  items: LoanInterestType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null)
                      setInnerState(() => selectedInterestType = value);
                  },
                ),
                DropdownButtonFormField<LoanPaymentFrequency>(
                  initialValue: selectedFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia de pago',
                  ),
                  items: LoanPaymentFrequency.values
                      .map(
                        (frequency) => DropdownMenuItem(
                          value: frequency,
                          child: Text(frequency.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null)
                      setInnerState(() => selectedFrequency = value);
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
                    decoration: const InputDecoration(
                      labelText: 'Día de la semana',
                    ),
                    items: List.generate(
                      7,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(_weekdayName(index + 1)),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null)
                        setInnerState(() => selectedWeekday = value);
                    },
                  ),
                if (selectedFrequency == LoanPaymentFrequency.custom)
                  TextFormField(
                    controller: customDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cada cuántos días',
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: disbursementDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null)
                      setInnerState(() => disbursementDate = picked);
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
                      initialDate:
                          firstPaymentDate ??
                          disbursementDate ??
                          DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null)
                      setInnerState(() => firstPaymentDate = picked);
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
                    final customDays =
                        int.tryParse(customDaysController.text) ?? 1;
                    if (nameController.text.trim().isEmpty ||
                        amount <= 0 ||
                        months <= 0 ||
                        paid < 0 ||
                        paid > months ||
                        (selectedFrequency == LoanPaymentFrequency.custom &&
                            customDays <= 0)) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Revisa el nombre, monto y número de cuotas.',
                          ),
                        ),
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
                        paymentDayOfMonth:
                            selectedFrequency == LoanPaymentFrequency.monthly
                            ? int.tryParse(dayController.text) ?? 1
                            : null,
                        paymentWeekday:
                            selectedFrequency == LoanPaymentFrequency.weekly
                            ? selectedWeekday
                            : null,
                        customEveryDays:
                            selectedFrequency == LoanPaymentFrequency.custom
                            ? customDays
                            : null,
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
                  const Text(
                    'Cotizador rápido',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                    onChanged: (_) => setInnerState(() {}),
                  ),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto en soles',
                    ),
                    onChanged: (_) => setInnerState(() {}),
                  ),
                  TextFormField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Interés %'),
                    onChanged: (_) => setInnerState(() {}),
                  ),
                  TextFormField(
                    controller: monthsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Número de cuotas',
                    ),
                    onChanged: (_) => setInnerState(() {}),
                  ),
                  DropdownButtonFormField<LoanInterestType>(
                    initialValue: selectedInterestType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de interés',
                    ),
                    items: LoanInterestType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null)
                        setInnerState(() => selectedInterestType = value);
                    },
                  ),
                  DropdownButtonFormField<LoanPaymentFrequency>(
                    initialValue: selectedFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Frecuencia de pago',
                    ),
                    items: LoanPaymentFrequency.values
                        .map(
                          (frequency) => DropdownMenuItem(
                            value: frequency,
                            child: Text(frequency.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null)
                        setInnerState(() => selectedFrequency = value);
                    },
                  ),
                  if (selectedFrequency == LoanPaymentFrequency.monthly)
                    TextFormField(
                      controller: dayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Día del mes',
                      ),
                    ),
                  if (selectedFrequency == LoanPaymentFrequency.weekly)
                    DropdownButtonFormField<int>(
                      initialValue: selectedWeekday,
                      decoration: const InputDecoration(
                        labelText: 'Día de la semana',
                      ),
                      items: List.generate(
                        7,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text(_weekdayName(index + 1)),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null)
                          setInnerState(() => selectedWeekday = value);
                      },
                    ),
                  if (selectedFrequency == LoanPaymentFrequency.custom)
                    TextFormField(
                      controller: customDaysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cada cuántos días',
                      ),
                    ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Ganancia estimada',
                    value: formatCurrency(profit),
                  ),
                  _SummaryRow(
                    label: 'Total a recibir',
                    value: formatCurrency(amount + profit),
                  ),
                  _SummaryRow(
                    label: 'Cuota estimada',
                    value: formatCurrency(installment),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty ||
                            amount <= 0 ||
                            months <= 0) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Completa cliente, monto y cuotas válidas.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _localChangeVersion++;
                          _quoteDrafts.insert(
                            0,
                            QuoteDraft(
                              borrowerName: nameController.text.trim(),
                              amount: amount,
                              interestRate: rate,
                              months: months,
                              interestType: selectedInterestType,
                              paymentFrequency: selectedFrequency,
                              paymentDayOfMonth:
                                  selectedFrequency ==
                                      LoanPaymentFrequency.monthly
                                  ? int.tryParse(dayController.text) ?? 1
                                  : null,
                              paymentWeekday:
                                  selectedFrequency ==
                                      LoanPaymentFrequency.weekly
                                  ? selectedWeekday
                                  : null,
                              customEveryDays:
                                  selectedFrequency ==
                                      LoanPaymentFrequency.custom
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
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Monto'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: rateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Interés %'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LoanInterestType>(
                      initialValue: selectedInterestType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de interés',
                      ),
                      items: LoanInterestType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null)
                          setInnerState(() => selectedInterestType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LoanPaymentFrequency>(
                      initialValue: selectedFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Frecuencia de pago',
                      ),
                      items: LoanPaymentFrequency.values
                          .map(
                            (frequency) => DropdownMenuItem(
                              value: frequency,
                              child: Text(frequency.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null)
                          setInnerState(() => selectedFrequency = value);
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
                        decoration: const InputDecoration(
                          labelText: 'Día del mes',
                        ),
                      ),
                    ],
                    if (selectedFrequency == LoanPaymentFrequency.weekly) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: selectedWeekday,
                        decoration: const InputDecoration(
                          labelText: 'Día de la semana',
                        ),
                        items: List.generate(
                          7,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text(_weekdayName(index + 1)),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null)
                            setInnerState(() => selectedWeekday = value);
                        },
                      ),
                    ],
                    if (selectedFrequency == LoanPaymentFrequency.custom) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: customDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cada cuántos días',
                        ),
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
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          selectedDate == null
                              ? 'Fecha de desembolso'
                              : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                          style: TextStyle(
                            color: selectedDate == null
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              firstPaymentDate ??
                              selectedDate ??
                              DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null)
                          setInnerState(() => firstPaymentDate = picked);
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
                          final amount =
                              double.tryParse(amountController.text) ?? 0;
                          final rate =
                              double.tryParse(rateController.text) ?? 0;
                          final months =
                              int.tryParse(monthsController.text) ?? 0;
                          final day = int.tryParse(dayController.text) ?? 1;
                          final customDays =
                              int.tryParse(customDaysController.text) ?? 1;

                          if (nameController.text.trim().isEmpty ||
                              amount <= 0 ||
                              months <= 0 ||
                              (selectedFrequency ==
                                      LoanPaymentFrequency.custom &&
                                  customDays <= 0)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Completa nombre, monto y meses válidos.',
                                ),
                              ),
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
                            firstPaymentDate:
                                firstPaymentDate ??
                                selectedDate ??
                                DateTime.now(),
                            interestType: selectedInterestType,
                            paymentFrequency: selectedFrequency,
                            paymentDayOfMonth:
                                selectedFrequency ==
                                    LoanPaymentFrequency.monthly
                                ? day
                                : null,
                            paymentWeekday:
                                selectedFrequency == LoanPaymentFrequency.weekly
                                ? selectedWeekday
                                : null,
                            customEveryDays:
                                selectedFrequency == LoanPaymentFrequency.custom
                                ? customDays
                                : null,
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
    if (_isLoadingState) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
        onDelete: _deleteLoan,
      ),
      AnalyticsScreen(
        loans: _loans,
        quotes: _quoteDrafts,
        onApprove: _approveQuote,
        onDelete: _deleteQuote,
      ),
      SettingsScreen(
        darkMode: widget.darkMode,
        themeColorIndex: widget.themeColorIndex,
        textScaleIndex: widget.textScaleIndex,
        onDarkModeChanged: widget.onDarkModeChanged,
        onThemeColorChanged: widget.onThemeColorChanged,
        onTextScaleChanged: widget.onTextScaleChanged,
        notificationsEnabled: _notificationsEnabled,
        reminderDaysBefore: _reminderDaysBefore,
        reminderTime: _reminderTime,
        onSaveNotificationSettings: _saveNotificationSettings,
        onTestNotification: _showTestNotification,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: IndexedStack(index: _selectedIndex, children: screens),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLoanSheet,
        tooltip: 'Nuevo préstamo',
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.darkMode
                ? [
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surface,
                  ]
                : [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.88),
                    Theme.of(context).colorScheme.tertiary,
                  ],
          ),
          boxShadow: widget.darkMode
              ? null
              : [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.28),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: Offset(0, -3),
                  ),
                  BoxShadow(
                    color: Theme.of(context).colorScheme.tertiary
                        .withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: Offset(0, -5),
                  ),
                ],
          border: Border(
            top: BorderSide(
              color: widget.darkMode
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.42),
              width: 0.7,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: widget.darkMode
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onPrimary,
          unselectedItemColor: widget.darkMode
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.72),
          selectedLabelStyle: TextStyle(
            color: widget.darkMode
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TextStyle(
            color: widget.darkMode
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onPrimary
                      .withValues(alpha: 0.72),
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'Préstamos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_rounded),
              label: 'Análisis',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Configuración',
            ),
          ],
        ),
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
    final totalExpected = loans.fold<double>(
      0,
      (sum, loan) => sum + loan.totalToReceive,
    );
    final recoveryProgress = totalExpected == 0
        ? 0.0
        : (metrics.collected / totalExpected).clamp(0.0, 1.0);
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
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onQuickQuote,
                  tooltip: 'Cotizador rápido',
                  icon: const Icon(Icons.calculate_outlined, size: 21),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PortfolioCreditCard(metrics: metrics),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                  _SummaryRow(
                    label: 'Capital colocado',
                    value: formatCurrency(metrics.capital),
                  ),
                  _SummaryRow(
                    label: 'Recaudado',
                    value: formatCurrency(metrics.collected),
                  ),
                  _SummaryRow(
                    label: 'Utilidad ya generada',
                    value: formatCurrency(metrics.collectedProfit),
                  ),
                  _SummaryRow(
                    label: 'Préstamos activos',
                    value: '${metrics.active.length}',
                  ),
                  _SummaryRow(
                    label: 'Préstamos atrasados',
                    value: '${metrics.overdue.length}',
                  ),
                  _SummaryRow(
                    label: 'Préstamos liquidados',
                    value: '${metrics.finished.length}',
                  ),
                  _SummaryRow(label: 'Borradores', value: '$pendingQuotes'),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Recuperación del total programado',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '${(recoveryProgress * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: recoveryProgress,
                      minHeight: 8,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF0A9C89),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionTitle(
              label: 'Próximos cobros',
              count: upcoming.length,
              color: Theme.of(context).colorScheme.primary,
            ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        late
                            ? Icons.warning_amber_rounded
                            : Icons.event_rounded,
                        color: late
                            ? const Color(0xFFB42318)
                            : const Color(0xFF0A9C89),
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.loan.borrowerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Cuota ${entry.installment.number} • ${_shortDateLabel(entry.installment.date)}${late ? ' • Atrasado' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatCurrency(entry.installment.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                );
              }),
            if (loans.isEmpty) ...[
              const SizedBox(height: 12),
              _EmptyPanel(
                message: 'Aún no hay préstamos registrados.',
                icon: Icons.receipt_long_rounded,
              ),
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
    required this.onDelete,
  });

  final List<LoanRecord> loans;
  final VoidCallback onQuickQuote;
  final void Function(LoanRecord loan) onEdit;
  final void Function(LoanRecord loan) onLoanTap;
  final void Function(LoanRecord loan) onDelete;

  Future<bool> _confirmDelete(BuildContext context, LoanRecord loan) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFB42318),
            ),
            title: const Text('¿Eliminar préstamo?'),
            content: Text(
              '¿Seguro que quieres borrar el préstamo de ${loan.borrowerName}? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB42318),
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Sí, eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _dismissibleLoan(BuildContext context, LoanRecord loan) {
    return Dismissible(
      key: ObjectKey(loan),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, loan),
      onDismissed: (_) => onDelete(loan),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB42318), Color(0xFF8F1D2C)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: _LoanCard(loan: loan, onEdit: onEdit, onTap: onLoanTap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = loans
        .where((loan) => loan.status == LoanStatus.active)
        .toList();
    final overdue = loans
        .where((loan) => loan.status == LoanStatus.overdue)
        .toList();
    final finished = loans
        .where((loan) => loan.status == LoanStatus.finished)
        .toList();
    final metrics = PortfolioMetrics(loans);
    final activeBalance = active.fold<double>(
      0,
      (sum, loan) => sum + loan.remainingBalance,
    );
    final overdueBalance = metrics.overdueBalance;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'PRÉSTAMOS',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
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
                    color: const Color(0xFF0A9C89),
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
                color: const Color(0xFF0A9C89),
              ),
              const SizedBox(height: 10),
              ...active.map((loan) => _dismissibleLoan(context, loan)),
            ],
            if (overdue.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionTitle(
                label: 'En mora',
                count: overdue.length,
                color: const Color(0xFFB42318),
              ),
              const SizedBox(height: 10),
              ...overdue.map((loan) => _dismissibleLoan(context, loan)),
            ],
            if (finished.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionTitle(
                label: 'Préstamos liquidados',
                count: finished.length,
                color: const Color(0xFF8B5E00),
              ),
              const SizedBox(height: 10),
              ...finished.map((loan) => _dismissibleLoan(context, loan)),
            ],
            if (loans.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 34,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
      (maximum, loan) =>
          loan.totalProfit > maximum ? loan.totalProfit : maximum,
    );
    final openCapital = [
      ...metrics.active,
      ...metrics.overdue,
    ].fold<double>(0, (sum, loan) => sum + loan.amount);
    final margin = openCapital == 0
        ? 0.0
        : (metrics.remainingProfit / openCapital) * 100;
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
            Text(
              'Rentabilidad, recuperación y calendario de cobros',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UTILIDAD PENDIENTE ESTIMADA',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary
                          .withValues(alpha: 0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatCurrency(metrics.remainingProfit),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Margen pendiente: ${margin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary
                          .withValues(alpha: 0.78),
                      fontSize: 12,
                    ),
                  ),
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
                    accent: Theme.of(context).colorScheme.primary,
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
                    accent: const Color(0xFF0A9C89),
                    icon: Icons.savings_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Utilidad generada',
                    value: formatCurrency(metrics.collectedProfit),
                    accent: Theme.of(context).colorScheme.secondary,
                    icon: Icons.trending_up_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionTitle(
              label: 'Estado de la cartera',
              count: loans.length,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Al día',
                    value: '${metrics.active.length} préstamos',
                  ),
                  _SummaryRow(
                    label: 'En mora',
                    value:
                        '${metrics.overdue.length} préstamos • ${formatCurrency(metrics.overdueBalance)}',
                  ),
                  _SummaryRow(
                    label: 'Liquidados',
                    value: '${metrics.finished.length} préstamos',
                  ),
                  _SummaryRow(
                    label: 'Cotizaciones guardadas',
                    value: '${quotes.length}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionTitle(
              label: 'Rentabilidad por préstamo',
              count: loans.length,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 8),
            if (loans.isEmpty)
              _EmptyPanel(
                message: 'Cuando registres préstamos, verás aquí su utilidad calculada.',
                icon: Icons.bar_chart_rounded,
              )
            else
              ...loans.map((loan) {
                final ratio = maximumProfit <= 0
                    ? 0.0
                    : (loan.totalProfit / maximumProfit).clamp(0.0, 1.0);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              loan.borrowerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            formatCurrency(loan.totalProfit),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
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
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _statusColor(loan),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${loan.interestRate.toStringAsFixed(1)}% • ${_statusText(loan)}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 18),
            _SectionTitle(
              label: 'Cobros en los próximos 30 días',
              count: upcoming.length,
              color: const Color(0xFFB77A00),
            ),
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              _EmptyPanel(
                message: 'No hay cuotas programadas en este periodo.',
                icon: Icons.event_note_rounded,
              )
            else
              ...upcoming.map(
                (entry) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(entry.loan.borrowerName),
                  subtitle: Text(
                    'Cuota ${entry.installment.number} • ${_shortDateLabel(entry.installment.date)}',
                  ),
                  trailing: Text(
                    formatCurrency(entry.installment.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            _SectionTitle(
              label: 'Cotizaciones en borrador',
              count: quotes.length,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 8),
            if (quotes.isEmpty)
              _EmptyPanel(
                message: 'No hay cotizaciones guardadas.',
                icon: Icons.request_quote_rounded,
              )
            else
              ...quotes.map(
                (quote) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: quote.approved
                                  ? const Color(0xFF2E8B57)
                                  : const Color(0xFF7A7A7A),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              quote.approved ? 'Aprobada' : 'Borrador',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        label: 'Monto',
                        value: formatCurrency(quote.amount),
                      ),
                      _SummaryRow(
                        label: 'Interés',
                        value: '${quote.interestRate.toStringAsFixed(1)}%',
                      ),
                      _SummaryRow(label: 'Meses', value: '${quote.months}'),
                      _SummaryRow(
                        label: 'Margen',
                        value: formatCurrency(quote.totalProfit),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => onApprove(quote),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(
                                quote.approved ? 'Aprobado' : 'Aprobar',
                              ),
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.darkMode,
    required this.themeColorIndex,
    required this.textScaleIndex,
    required this.onDarkModeChanged,
    required this.onThemeColorChanged,
    required this.onTextScaleChanged,
    required this.notificationsEnabled,
    required this.reminderDaysBefore,
    required this.reminderTime,
    required this.onSaveNotificationSettings,
    required this.onTestNotification,
  });

  final bool darkMode;
  final int themeColorIndex;
  final int textScaleIndex;
  final Future<bool> Function(bool value)? onDarkModeChanged;
  final Future<bool> Function(int value)? onThemeColorChanged;
  final Future<bool> Function(int value)? onTextScaleChanged;
  final bool notificationsEnabled;
  final int reminderDaysBefore;
  final TimeOfDay reminderTime;
  final Future<bool> Function(bool enabled, int daysBefore, TimeOfDay time)
  onSaveNotificationSettings;
  final Future<void> Function() onTestNotification;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        children: [
          Text(
            'Configuración',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Personaliza cómo quieres usar Jean Lucas Credit.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Card(
            child: SwitchListTile.adaptive(
              secondary: Icon(
                darkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              ),
              title: const Text('Modo noche'),
              subtitle: Text(darkMode ? 'Modo noche activado' : 'Modo día'),
              value: darkMode,
              onChanged: onDarkModeChanged == null
                  ? null
                  : (value) => _saveSetting(context, onDarkModeChanged!(value)),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Apariencia'),
              subtitle: Text(
                '${_appearancePalettes[themeColorIndex].name} · ${_textScaleLabels[textScaleIndex]}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onThemeColorChanged == null || onTextScaleChanged == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AppearanceScreen(
                            themeColorIndex: themeColorIndex,
                            textScaleIndex: textScaleIndex,
                            onThemeColorChanged: onThemeColorChanged!,
                            onTextScaleChanged: onTextScaleChanged!,
                          ),
                        ),
                      );
                    },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Notificaciones'),
              subtitle: Text(
                notificationsEnabled
                    ? 'Activas · ${reminderDaysBefore == 0 ? 'el mismo día' : '$reminderDaysBefore día(s) antes'} a las ${reminderTime.format(context)}'
                    : 'Configura los recordatorios de pago.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NotificationSettingsScreen(
                      enabled: notificationsEnabled,
                      daysBefore: reminderDaysBefore,
                      reminderTime: reminderTime,
                      onSave: onSaveNotificationSettings,
                      onTest: onTestNotification,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Acerca de'),
              subtitle: Text('Jean Lucas Credit · Gestión de préstamos'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _saveSetting(BuildContext context, Future<bool> save) async {
  final saved = await save;
  if (!context.mounted || saved) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No se pudo guardar la configuración.')),
  );
}

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({
    super.key,
    required this.themeColorIndex,
    required this.textScaleIndex,
    required this.onThemeColorChanged,
    required this.onTextScaleChanged,
  });

  final int themeColorIndex;
  final int textScaleIndex;
  final Future<bool> Function(int value) onThemeColorChanged;
  final Future<bool> Function(int value) onTextScaleChanged;

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late int _themeColorIndex = widget.themeColorIndex;
  late int _textScaleIndex = widget.textScaleIndex;

  Future<void> _changeColor(int index) async {
    final previousIndex = _themeColorIndex;
    setState(() => _themeColorIndex = index);
    if (!await widget.onThemeColorChanged(index) && mounted) {
      setState(() => _themeColorIndex = previousIndex);
      _showSaveError();
    }
  }

  Future<void> _changeTextScale(int index) async {
    final previousIndex = _textScaleIndex;
    setState(() => _textScaleIndex = index);
    if (!await widget.onTextScaleChanged(index) && mounted) {
      setState(() => _textScaleIndex = previousIndex);
      _showSaveError();
    }
  }

  void _showSaveError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo guardar la apariencia.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Color del tema', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_appearancePalettes.length, (index) {
                  final palette = _appearancePalettes[index];
                  final isSelected = index == _themeColorIndex;
                  return Semantics(
                    label: palette.name,
                    button: true,
                    selected: isSelected,
                    child: InkWell(
                      key: ValueKey('appearance-color-$index'),
                      onTap: () => _changeColor(index),
                      customBorder: const CircleBorder(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.color,
                          border: Border.all(
                            color: isSelected
                                ? scheme.onSurface
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                color: ThemeData.estimateBrightnessForColor(
                                          palette.color,
                                        ) ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                                size: 21,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tamaño del texto',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: List.generate(_textScaleValues.length, (index) {
                  final isSelected = index == _textScaleIndex;
                  return Expanded(
                    child: Semantics(
                      label: _textScaleLabels[index],
                      button: true,
                      selected: isSelected,
                      child: InkWell(
                        key: ValueKey('appearance-text-scale-$index'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _changeTextScale(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          height: 54,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'aA',
                            style: TextStyle(
                              color: isSelected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                              fontSize: 15 + index * 4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Vista previa: Jean Lucas Credit',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({
    super.key,
    required this.enabled,
    required this.daysBefore,
    required this.reminderTime,
    required this.onSave,
    required this.onTest,
  });

  final bool enabled;
  final int daysBefore;
  final TimeOfDay reminderTime;
  final Future<bool> Function(bool enabled, int daysBefore, TimeOfDay time)
  onSave;
  final Future<void> Function() onTest;

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late bool _enabled;
  late int _daysBefore;
  late TimeOfDay _reminderTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
    _daysBefore = widget.daysBefore;
    _reminderTime = widget.reminderTime;
  }

  Future<void> _save({bool? enabled}) async {
    setState(() => _saving = true);
    final saved = await widget.onSave(
      enabled ?? _enabled,
      _daysBefore,
      _reminderTime,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved && enabled != null) _enabled = enabled;
    });
    if (saved && enabled == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferencias de recordatorio guardadas.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: SwitchListTile.adaptive(
              value: _enabled,
              onChanged: _saving ? null : (value) => _save(enabled: value),
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Recordatorios de pago'),
              subtitle: Text(
                _enabled ? 'Activos para este dispositivo.' : 'Desactivados',
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Cuándo avisar',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioGroup<int>(
                  groupValue: _daysBefore <= 1 ? _daysBefore : null,
                  onChanged: (value) {
                    if (!_saving && value != null)
                      setState(() => _daysBefore = value);
                  },
                  child: Column(
                    children: const [
                      RadioListTile<int>(value: 1, title: Text('Un día antes')),
                      RadioListTile<int>(value: 0, title: Text('El mismo día')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Días antes (hasta 30)')),
                      DropdownButton<int>(
                        value: _daysBefore > 1 ? _daysBefore : null,
                        hint: const Text('Elegir'),
                        items: List.generate(29, (index) => index + 2)
                            .map(
                              (days) => DropdownMenuItem(
                                value: days,
                                child: Text('$days días'),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                if (value != null)
                                  setState(() => _daysBefore = value);
                              },
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('Hora del recordatorio'),
                  subtitle: Text(_reminderTime.format(context)),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _saving
                      ? null
                      : () async {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: _reminderTime,
                          );
                          if (selected != null && mounted)
                            setState(() => _reminderTime = selected);
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'El aviso se programa a la hora elegida según la fecha de cada cuota. En Android, el sistema puede entregar avisos aproximados con unos minutos de diferencia.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Guardar configuración'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: !_enabled || _saving ? null : widget.onTest,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Enviar notificación de prueba'),
          ),
        ],
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF60758B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
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

class _PortfolioCreditCard extends StatefulWidget {
  const _PortfolioCreditCard({required this.metrics});

  final PortfolioMetrics metrics;

  @override
  State<_PortfolioCreditCard> createState() => _PortfolioCreditCardState();
}

class _PortfolioCreditCardState extends State<_PortfolioCreditCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                colorScheme.primary.withValues(alpha: 0.86),
                colorScheme.tertiary,
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: colorScheme.onPrimary.withValues(alpha: 0.3),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: colorScheme.tertiary.withValues(alpha: 0.16),
                blurRadius: 28,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -32,
                top: -62,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.onPrimary.withValues(alpha: 0.12),
                      width: 26,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          color: colorScheme.onPrimary,
                          size: 23,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'JEAN LUCAS CREDIT',
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.contactless_rounded,
                          color: colorScheme.onPrimary.withValues(alpha: 0.82),
                          size: 25,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 43,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFE7A3), Color(0xFFDEA84F)],
                        ),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0x77FFFFFF)),
                      ),
                      child: const Icon(
                        Icons.memory_rounded,
                        color: Color(0xFF7D612A),
                        size: 21,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SALDOS PRESTADOS',
                      style: TextStyle(
                        color: colorScheme.onPrimary.withValues(alpha: 0.78),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatCurrency(metrics.capital),
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 31,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: _CreditCardAmount(
                            label: 'Por recuperar',
                            value: formatCurrency(metrics.outstanding),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CreditCardAmount(
                            label: 'Cobros 30 días',
                            value: formatCurrency(metrics.next30DaysCollection),
                          ),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                      child: _expanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Container(
                                padding: const EdgeInsets.only(top: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: colorScheme.onPrimary.withValues(
                                        alpha: 0.34,
                                      ),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _CreditCardAmount(
                                        label: 'Recaudado',
                                        value: formatCurrency(
                                          metrics.collected,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _CreditCardAmount(
                                        label: 'En mora',
                                        value: formatCurrency(
                                          metrics.overdueBalance,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _CreditCardAmount(
                                        label: 'Préstamos',
                                        value: '${metrics.loans.length}',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Text(
                          _expanded
                              ? 'Toca para ocultar detalles'
                              : 'Toca para ver detalles',
                          style: TextStyle(
                            color: colorScheme.onPrimary.withValues(
                              alpha: 0.75,
                            ),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 220),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: colorScheme.onPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditCardAmount extends StatelessWidget {
  const _CreditCardAmount({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: onPrimary.withValues(alpha: 0.72),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: onPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
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
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            detail,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.label,
    required this.count,
    required this.color,
  });

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
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.onEdit,
    required this.onTap,
  });

  final LoanRecord loan;
  final void Function(LoanRecord loan) onEdit;
  final void Function(LoanRecord loan) onTap;

  @override
  Widget build(BuildContext context) {
    final due = loan.nextDueDate;
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBg(context, loan),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusText(loan),
                      style: TextStyle(
                        color: _statusColor(loan),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    onPressed: () => onEdit(loan),
                    tooltip: 'Editar préstamo',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      foregroundColor: colorScheme.onSurface,
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
                      loan.isPaidAll
                          ? 'Préstamo liquidado'
                          : 'Cuota ${loan.paidMonths + 1} de ${loan.months}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    formatCurrency(loan.isPaidAll ? 0 : loan.monthlyPayment),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (due != null) ...[
                const SizedBox(height: 5),
                Text(
                  'Próximo vencimiento: ${due.day} ${_shortMonth(due)}',
                  style: TextStyle(
                    color: loan.status == LoanStatus.overdue
                        ? _statusColor(loan)
                        : colorScheme.secondary,
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
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
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
        content: Text(
          '¿Confirmas el pago de ${formatCurrency(_loan.monthlyPayment)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cronograma de pagos')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            _loan.borrowerName,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            label: 'Monto total a recibir',
            value: formatCurrency(_loan.totalToReceive),
          ),
          _SummaryRow(
            label: 'Saldo pendiente',
            value: formatCurrency(_loan.remainingBalance),
          ),
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
          const Text(
            'Cuotas programadas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...installments.map(
            (installment) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: installment.isPaid
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                child: Icon(
                  installment.isPaid
                      ? Icons.check_rounded
                      : Icons.event_rounded,
                  color: installment.isPaid
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                  size: 18,
                ),
              ),
              title: Text('Cuota ${installment.number}'),
              subtitle: Text(
                '${installment.date.day}/${installment.date.month}/${installment.date.year}',
              ),
              trailing: Text(
                installment.isPaid
                    ? 'Pagada'
                    : formatCurrency(installment.amount),
                style: TextStyle(
                  color: installment.isPaid ? colorScheme.primary : null,
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
