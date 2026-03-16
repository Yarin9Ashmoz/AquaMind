import 'package:flutter/material.dart';
import '../../data/models/sensor.dart';
import '../../data/repositories/sensor_repository.dart';

class DashboardState extends ChangeNotifier {
  final SensorRepository repo;

  List<Sensor> sensors = [];
  Sensor? selectedSensor;
  bool isLoading = false;
  String? error;

  DashboardState(this.repo) {
    loadSensors(); // טעינה ראשונית של החיישנים
  }

  // פונקציה לטעינת חיישנים מהשרת
  Future<void> loadSensors() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      sensors = await repo.getSensors();

      // עדכון החיישן הנבחר בנתונים החדשים
      if (selectedSensor != null) {
        try {
          selectedSensor = sensors.firstWhere(
            (s) => s.sensorId == selectedSensor!.sensorId,
          );
        } catch (_) {
          // אם החיישן כבר לא קיים ברשימה החדשה
          selectedSensor = sensors.isNotEmpty ? sensors.first : null;
        }
      } else if (sensors.isNotEmpty) {
        selectedSensor = sensors.first;
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      error = e.toString();
      notifyListeners();
      print("❌ Error loading sensors: $e");
    }
  }

  // Alias למקרה שקראת לפונקציה בשם fetchSensors במסכים אחרים
  Future<void> fetchSensors() => loadSensors();

  // --- הפונקציה שהייתה חסרה ---
  Future<void> deleteAllSensors() async {
    try {
      isLoading = true;
      notifyListeners();

      // מחיקה בשרת דרך ה-Repository
      await repo.deleteAllSensors();

      // ניקוי מקומי של הרשימה
      sensors = [];
      selectedSensor = null;

      isLoading = false;
      notifyListeners();
      print("✅ All sensors deleted successfully");
    } catch (e) {
      isLoading = false;
      error = "Failed to delete all sensors: $e";
      notifyListeners();
      print("❌ Error deleting all sensors: $e");
    }
  }

  // מחיקת חיישן בודד
  Future<void> deleteSensorById(String sensorId) async {
    try {
      await repo.deleteSensor(sensorId: sensorId);
      sensors.removeWhere((s) => s.sensorId == sensorId);
      if (selectedSensor?.sensorId == sensorId) {
        selectedSensor = sensors.isNotEmpty ? sensors.first : null;
      }
      notifyListeners();
    } catch (e) {
      error = "Delete failed: $e";
      notifyListeners();
    }
  }

  // מחיקת חיישן לפי שם
  Future<void> deleteSensorByName(String name) async {
    try {
      await repo.deleteSensor(name: name);
      sensors.removeWhere((s) => s.name == name);
      if (selectedSensor?.name == name) {
        selectedSensor = sensors.isNotEmpty ? sensors.first : null;
      }
      notifyListeners();
    } catch (e) {
      error = "Delete failed: $e";
      notifyListeners();
    }
  }

  // שינוי שם
  Future<void> renameSensor(String sensorId, String newName) async {
    try {
      await repo.renameSensor(sensorId, newName);
      await loadSensors(); // רענון נתונים
    } catch (e) {
      error = "Rename failed: $e";
      notifyListeners();
    }
  }

  // יצירת חיישן
  Future<void> createSensor({
    required String sensorId,
    required String name,
    required String plantType,
    required String locationType,
    required double moisture,
  }) async {
    try {
      await repo.createSensor(
        sensorId: sensorId,
        name: name,
        plantType: plantType,
        locationType: locationType,
        moisture: moisture,
      );
      await loadSensors();
    } catch (e) {
      error = "Creation failed: $e";
      notifyListeners();
    }
  }

  // בחירת חיישן ידנית (למשל בלחיצה על רשימה)
  void selectSensor(Sensor sensor) {
    selectedSensor = sensor;
    notifyListeners();
  }

  // --- Getters לעיצוב ---
  String get statusText {
    if (selectedSensor == null) return "No data";
    final m = selectedSensor!.moisture;
    if (m < 30) return "Dry – needs watering";
    if (m < 60) return "Moisture level is normal";
    return "Too wet";
  }

  String get lastUpdateText {
    if (selectedSensor == null) return "";
    return selectedSensor!.lastUpdate.toString();
  }
}
