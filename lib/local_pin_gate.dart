import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalPinGate extends StatefulWidget {
  const LocalPinGate({super.key, required this.child});

  final Widget child;

  @override
  State<LocalPinGate> createState() => _LocalPinGateState();
}

class _LocalPinGateState extends State<LocalPinGate>
    with WidgetsBindingObserver {
  static const _pinKey = 'jean_lucas_local_pin';

  final _controller = TextEditingController();
  String? _savedPin;
  String? _firstEntry;
  String? _error;
  bool _loading = true;
  bool _unlocked = false;
  bool _processing = false;
  String? _storageError;

  bool get _confirmingPin => _firstEntry != null;
  bool get _creatingPin => _savedPin == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached) &&
        _unlocked) {
      setState(() {
        _unlocked = false;
        _error = null;
        _controller.clear();
      });
    }
  }

  Future<void> _loadPin() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedPin = preferences.getString(_pinKey);
      if (savedPin != null && !RegExp(r'^\d{4}$').hasMatch(savedPin)) {
        throw const FormatException(
          'El PIN guardado no tiene un formato válido.',
        );
      }
      if (!mounted) return;
      setState(() {
        _savedPin = savedPin;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _storageError = 'No se pudo leer el PIN guardado: $error';
        _loading = false;
      });
    }
  }

  Future<void> _submitPin(String pin) async {
    if (pin.length != 4 || _processing) return;
    _processing = true;

    if (_creatingPin && !_confirmingPin) {
      setState(() {
        _firstEntry = pin;
        _error = null;
        _controller.clear();
      });
      _processing = false;
      return;
    }

    if (_confirmingPin) {
      if (pin != _firstEntry) {
        setState(() {
          _firstEntry = null;
          _error = 'Los PIN no coinciden. Inténtalo de nuevo.';
          _controller.clear();
        });
        _processing = false;
        return;
      }

      try {
        final preferences = await SharedPreferences.getInstance();
        final saved = await preferences.setString(_pinKey, pin);
        if (!saved) {
          throw StateError('El dispositivo no confirmó el guardado del PIN.');
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _error = 'No se pudo guardar tu PIN. Inténtalo de nuevo: $error';
            _controller.clear();
          });
        }
        _processing = false;
        return;
      }
      if (!mounted) {
        _processing = false;
        return;
      }
      setState(() {
        _savedPin = pin;
        _firstEntry = null;
        _unlocked = true;
        _error = null;
        _controller.clear();
      });
      _processing = false;
      return;
    }

    if (pin == _savedPin) {
      setState(() {
        _unlocked = true;
        _error = null;
        _controller.clear();
      });
    } else {
      setState(() {
        _error = 'PIN incorrecto. Inténtalo de nuevo.';
        _controller.clear();
      });
    }
    _processing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_storageError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_storageError!, textAlign: TextAlign.center),
            ),
          ),
        ),
      );
    }
    if (_unlocked) return widget.child;

    final title = _creatingPin
        ? (_confirmingPin ? 'Confirma tu PIN' : 'Crea tu PIN')
        : 'Ingresa tu PIN';
    final message = _creatingPin
        ? (_confirmingPin
              ? 'Vuelve a escribir los 4 dígitos para confirmar.'
              : 'Elige una contraseña numérica de 4 dígitos para proteger el acceso local.')
        : 'Ingresa tu contraseña numérica de 4 dígitos.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 56,
                    color: Color(0xFF087F8C),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'JEAN LUCAS CREDIT',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    maxLength: 4,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'PIN de 4 dígitos',
                      counterText: '',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    onChanged: _submitPin,
                    onSubmitted: _submitPin,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
