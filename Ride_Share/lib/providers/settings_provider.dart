import 'package:flutter/foundation.dart';
import 'package:ride_share_app/models/settings_model.dart';
import 'package:ride_share_app/services/database_service.dart';

class SettingsProvider with ChangeNotifier {
  DatabaseService? _databaseService;
  Settings? _settings;
  bool _isLoading = false;
  String? _error;

  Settings? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateDatabaseService(DatabaseService databaseService) {
    _databaseService = databaseService;
  }

  Future<void> fetchSettings() async {
    if (_databaseService == null) {
      _error = "Database service not available.";
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final settingsData = await _databaseService!.getSettings();
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
    if (_databaseService == null) {
      _error = "Database service not available.";
      notifyListeners();
      return;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final settingsData = await _databaseService!.updateSettings(settings.toMap());
      _settings = Settings.fromMap(settingsData);
    } catch (e) {
      _error = "An error occurred while updating settings: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
