import 'package:flutter/foundation.dart';
import 'package:ride_share_app/models/settings_model.dart';
import 'package/ride_share_app/services/database_service.dart';

class SettingsProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  Settings? _settings;
  bool _isLoading = false;
  String? _error;

  Settings? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SettingsProvider() {
    fetchSettings();
  }

  Future<void> fetchSettings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final settingsData = await _databaseService.getSettings();
      if (settingsData != null) {
        _settings = Settings.fromMap(settingsData);
      } else {
        _error = "Could not load application settings.";
      }
    } catch (e) {
      _error = "An error occurred while fetching settings: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(Settings settings) async {
     _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final settingsData = await _databaseService.updateSettings(settings.toMap());
      _settings = Settings.fromMap(settingsData);
    } catch (e) {
      _error = "An error occurred while updating settings: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
