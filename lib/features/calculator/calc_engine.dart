class CalcEngine {
  String display = '0';
  double? _accumulator;
  String? _operator;
  bool _replace = true;
  bool hasError = false;

  void inputDigit(String digit) {
    if (hasError) {
      clear();
    }
    if (_replace) {
      display = digit;
      _replace = false;
      return;
    }
    if (display == '0') {
      display = digit;
      return;
    }
    if (display.replaceAll('-', '').replaceAll('.', '').length >= 12) {
      return;
    }
    display += digit;
  }

  void inputDot() {
    if (hasError) {
      clear();
    }
    if (_replace) {
      display = '0.';
      _replace = false;
      return;
    }
    if (!display.contains('.')) {
      display += '.';
    }
  }

  void inputOperator(String operator) {
    if (hasError) {
      return;
    }
    final current = double.tryParse(display);
    if (current == null) {
      return;
    }
    if (_accumulator != null && _operator != null && !_replace) {
      if (!_apply(current)) {
        return;
      }
    } else {
      _accumulator = current;
    }
    _operator = operator;
    _replace = true;
  }

  void equals() {
    if (hasError || _operator == null || _accumulator == null) {
      return;
    }
    final current = double.tryParse(display);
    if (current == null) {
      return;
    }
    if (_apply(current)) {
      _operator = null;
      _accumulator = null;
      _replace = true;
    }
  }

  void clear() {
    display = '0';
    _accumulator = null;
    _operator = null;
    _replace = true;
    hasError = false;
  }

  void backspace() {
    if (hasError || _replace) {
      return;
    }
    if (display.length <= 1 || (display.startsWith('-') && display.length == 2)) {
      display = '0';
      _replace = true;
      return;
    }
    display = display.substring(0, display.length - 1);
  }

  void toggleSign() {
    if (hasError || display == '0') {
      return;
    }
    if (display.startsWith('-')) {
      display = display.substring(1);
    } else {
      display = '-$display';
    }
  }

  double? get numericValue => hasError ? null : double.tryParse(display);

  CalcEngine duplicate() {
    final next = CalcEngine();
    next.display = display;
    next.hasError = hasError;
    next._accumulator = _accumulator;
    next._operator = _operator;
    next._replace = _replace;
    return next;
  }

  bool _apply(double current) {
    final acc = _accumulator;
    final op = _operator;
    if (acc == null || op == null) {
      return false;
    }
    if ((op == '÷' || op == '/') && current == 0) {
      display = 'Error';
      hasError = true;
      _accumulator = null;
      _operator = null;
      _replace = true;
      return false;
    }
    final result = switch (op) {
      '+' => acc + current,
      '-' => acc - current,
      '×' || '*' => acc * current,
      '÷' || '/' => acc / current,
      _ => current,
    };
    display = formatCalc(result);
    _accumulator = result;
    return true;
  }
}

String formatCalc(double value) {
  if (value.isNaN || value.isInfinite) {
    return 'Error';
  }
  final rounded = (value * 1e10).round() / 1e10;
  if (rounded == rounded.roundToDouble()) {
    return rounded.toInt().toString();
  }
  var text = rounded.toString();
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}
