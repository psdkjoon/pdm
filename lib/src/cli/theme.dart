String _ansi(int code, String text, bool colorEnabled) =>
    colorEnabled ? '\x1B[${code}m$text\x1B[0m' : text;
String _rgb(int r, int g, int b, String text, bool colorEnabled) =>
    colorEnabled ? '\x1B[38;2;$r;$g;${b}m$text\x1B[0m' : text;

abstract class CliTheme {
  final bool colorEnabled;
  CliTheme(this.colorEnabled);
  String bar(double progress, {int width = 30});
  String success(String text);
  String error(String text);
  String warn(String text);
  String info(String text);
  String muted(String text);
  String bold(String text);
}

class DefaultTheme extends CliTheme {
  DefaultTheme(super.colorEnabled);
  @override
  String bar(double progress, {int width = 30}) {
    final filled = (progress.clamp(0, 1) * width).round();
    final bar = '█' * filled + '░' * (width - filled);
    return _ansi(36, bar, colorEnabled);
  }

  @override
  String success(String text) => _ansi(32, text, colorEnabled);
  @override
  String error(String text) => _ansi(31, text, colorEnabled);
  @override
  String warn(String text) => _ansi(33, text, colorEnabled);
  @override
  String info(String text) => _ansi(36, text, colorEnabled);
  @override
  String muted(String text) => _ansi(90, text, colorEnabled);
  @override
  String bold(String text) => _ansi(1, text, colorEnabled);
}

class RainbowTheme extends CliTheme {
  RainbowTheme(super.colorEnabled);
  static const _colors = [196, 208, 220, 46, 51, 21, 93, 201];
  @override
  String bar(double progress, {int width = 30}) {
    final filled = (progress.clamp(0, 1) * width).round();
    final buf = StringBuffer();
    for (var i = 0; i < width; i++) {
      final ch = i < filled ? '█' : '░';
      final color = _colors[i % _colors.length];
      buf.write(colorEnabled ? '\x1B[38;5;${color}m$ch\x1B[0m' : ch);
    }
    return buf.toString();
  }

  @override
  String success(String text) => _ansi(92, text, colorEnabled);
  @override
  String error(String text) => _ansi(91, text, colorEnabled);
  @override
  String warn(String text) => _ansi(93, text, colorEnabled);
  @override
  String info(String text) => _ansi(96, text, colorEnabled);
  @override
  String muted(String text) => _ansi(90, text, colorEnabled);
  @override
  String bold(String text) => _ansi(1, text, colorEnabled);
}

class CatppuccinTheme extends CliTheme {
  CatppuccinTheme(super.colorEnabled);
  static const _mauve = (203, 166, 247);
  static const _green = (166, 227, 161);
  static const _red = (243, 139, 168);
  static const _yellow = (249, 226, 175);
  static const _sky = (137, 220, 235);
  static const _overlay = (108, 112, 134);
  static const _text = (205, 214, 244);
  @override
  String bar(double progress, {int width = 30}) {
    final filled = (progress.clamp(0, 1) * width).round();
    final (r, g, b) = _mauve;
    final filledPart = _rgb(r, g, b, '█' * filled, colorEnabled);
    final (or_, og, ob) = _overlay;
    final emptyPart = _rgb(or_, og, ob, '░' * (width - filled), colorEnabled);
    return '$filledPart$emptyPart';
  }

  @override
  String success(String text) {
    final (r, g, b) = _green;
    return _rgb(r, g, b, text, colorEnabled);
  }

  @override
  String error(String text) {
    final (r, g, b) = _red;
    return _rgb(r, g, b, text, colorEnabled);
  }

  @override
  String warn(String text) {
    final (r, g, b) = _yellow;
    return _rgb(r, g, b, text, colorEnabled);
  }

  @override
  String info(String text) {
    final (r, g, b) = _sky;
    return _rgb(r, g, b, text, colorEnabled);
  }

  @override
  String muted(String text) {
    final (r, g, b) = _overlay;
    return _rgb(r, g, b, text, colorEnabled);
  }

  @override
  String bold(String text) {
    final (r, g, b) = _text;
    return colorEnabled ? '\x1B[1m${_rgb(r, g, b, text, true)}' : text;
  }
}

CliTheme themeByName(String name, {required bool colorEnabled}) {
  switch (name.toLowerCase()) {
    case 'rainbow':
      return RainbowTheme(colorEnabled);
    case 'catppuccin':
      return CatppuccinTheme(colorEnabled);
    case 'default':
    default:
      return DefaultTheme(colorEnabled);
  }
}
