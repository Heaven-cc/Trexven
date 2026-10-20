import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signature navy is the Owner App default when no saved choice exists.
enum OwnerAppearance { trexven, system, light, dark }

class ThemeProvider with ChangeNotifier {
  OwnerAppearance _appearance = OwnerAppearance.trexven;
  int _revision = 0;

  ThemeProvider() {
    _loadTheme();
  }

  OwnerAppearance get appearance => _appearance;

  ThemeMode get themeMode => switch (_appearance) {
    OwnerAppearance.light => ThemeMode.light,
    OwnerAppearance.system => ThemeMode.system,
    OwnerAppearance.dark || OwnerAppearance.trexven => ThemeMode.dark,
  };

  Future<void> setAppearance(OwnerAppearance appearance) async {
    final revision = ++_revision;
    _appearance = appearance;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (revision == _revision) {
      await prefs.setString('theme_mode', appearance.name);
    }
  }

  // Compatibility for callers using the three standard Flutter theme modes.
  void setThemeMode(ThemeMode mode) {
    setAppearance(switch (mode) {
      ThemeMode.system => OwnerAppearance.system,
      ThemeMode.light => OwnerAppearance.light,
      ThemeMode.dark => OwnerAppearance.dark,
    });
  }

  void _loadTheme() async {
    final revision = _revision;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('theme_mode');
      final resolved = OwnerAppearance.values.firstWhere(
        (value) => value.name == saved,
        orElse: () => OwnerAppearance.trexven,
      );
      if (revision != _revision) return;
      _appearance = resolved;
      notifyListeners();
    } catch (_) {
      // A missing device preference safely retains the signature appearance.
    }
  }
}
