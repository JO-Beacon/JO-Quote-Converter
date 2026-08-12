import 'package:shared_preferences/shared_preferences.dart';

class SavedDraft {
  const SavedDraft({
    required this.input,
    required this.output,
    required this.excludeMarkdownCode,
    required this.useHeuristics,
  });

  final String input;
  final String output;
  final bool excludeMarkdownCode;
  final bool useHeuristics;
}

class DraftStore {
  static const _inputKey = 'draft.input';
  static const _outputKey = 'draft.output';
  static const _excludeMarkdownCodeKey = 'draft.excludeMarkdownCode';
  static const _useHeuristicsKey = 'draft.useHeuristics';
  static const _themeModeKey = 'settings.themeMode';
  static const _paletteKey = 'settings.palette';

  final Future<SharedPreferences> _preferences =
      SharedPreferences.getInstance();

  Future<SavedDraft> load() async {
    final preferences = await _preferences;
    return SavedDraft(
      input: preferences.getString(_inputKey) ?? '',
      output: preferences.getString(_outputKey) ?? '',
      excludeMarkdownCode: preferences.getBool(_excludeMarkdownCodeKey) ?? true,
      useHeuristics: preferences.getBool(_useHeuristicsKey) ?? true,
    );
  }

  Future<void> save(SavedDraft draft) async {
    final preferences = await _preferences;
    await preferences.setString(_inputKey, draft.input);
    await preferences.setString(_outputKey, draft.output);
    await preferences.setBool(
      _excludeMarkdownCodeKey,
      draft.excludeMarkdownCode,
    );
    await preferences.setBool(_useHeuristicsKey, draft.useHeuristics);
  }

  Future<String?> loadThemeMode() async {
    final preferences = await _preferences;
    return preferences.getString(_themeModeKey);
  }

  Future<void> saveThemeMode(String themeMode) async {
    final preferences = await _preferences;
    await preferences.setString(_themeModeKey, themeMode);
  }

  Future<String?> loadPalette() async {
    final preferences = await _preferences;
    return preferences.getString(_paletteKey);
  }

  Future<void> savePalette(String palette) async {
    final preferences = await _preferences;
    await preferences.setString(_paletteKey, palette);
  }
}
