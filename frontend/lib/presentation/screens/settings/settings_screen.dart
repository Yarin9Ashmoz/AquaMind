import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/dashboard_state.dart'; // וודא שהנתיב ל-State נכון

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "System Settings",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle("Monitoring & Alerts"),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.notifications_active,
                    color: Colors.orange,
                  ),
                  title: const Text("Moisture Alerts"),
                  subtitle: const Text(
                    "Get a notification when your plant needs water",
                  ),
                  value: true,
                  onChanged: (val) {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shutter_speed, color: Colors.blue),
                  title: const Text("Alert Threshold"),
                  subtitle: Slider(
                    value: 25,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: "25%",
                    onChanged: (v) {},
                  ),
                  trailing: const Text(
                    "25%",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle("Device Configuration"),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.timer, color: Colors.green),
                  title: const Text("Data Sync Interval"),
                  subtitle: const Text("Every 30 minutes"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.wifi, color: Colors.purple),
                  title: const Text("Network Status"),
                  trailing: const Text(
                    "Connected",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle("Danger Zone"), // הוספת כותרת לאזור רגיש
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    "Delete All Sensors",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text("Wipe all data from the database"),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.red,
                  ),
                  onTap: () => _showDeleteConfirmation(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_remove, color: Colors.red),
                  title: const Text(
                    "Delete Sensor by Name/ID",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    "Remove a single sensor from the database",
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.red,
                  ),
                  onTap: () => _showDeleteSingleSensorDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle("Cloud Server"),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.cloud_done, color: Colors.cyan),
              title: const Text("Server Status"),
              subtitle: const Text("Render Cloud - Singapore"),
              trailing: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.refresh, color: Colors.grey),
            label: const Text(
              "Reset All Settings",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  /// מציג דיאלוג אישור לפני מחיקה
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text(
          "Are you sure you want to delete all sensors? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); // סגירת הדיאלוג

              try {
                // הפעלת פונקציית המחיקה מה-State
                await context.read<DashboardState>().deleteAllSensors();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("All sensors deleted successfully"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Failed to delete: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Delete Everything",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteSingleSensorDialog(BuildContext context) {
    final controller = TextEditingController();
    var selectedType = 'sensorId';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Sensor"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedType,
              items: const [
                DropdownMenuItem(value: 'sensorId', child: Text('Sensor ID')),
                DropdownMenuItem(value: 'name', child: Text('Sensor Name')),
              ],
              onChanged: (value) {
                if (value != null) selectedType = value;
              },
              decoration: const InputDecoration(labelText: 'Delete by'),
            ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'ID or Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty) return;

              Navigator.pop(ctx);

              try {
                if (selectedType == 'sensorId') {
                  await context.read<DashboardState>().deleteSensorById(value);
                } else {
                  await context.read<DashboardState>().deleteSensorByName(
                    value,
                  );
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Deleted sensor with $selectedType "$value"',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete sensor: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
