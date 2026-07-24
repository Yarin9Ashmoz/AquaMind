import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/dashboard_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _moistureAlertsEnabled = true;
  double _alertThreshold = 25.0;
  int _syncIntervalMinutes = 30;

  @override
  void initState() {
    super.initState();
    // Load existing sensor configurations from state upon screen initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dashboardState = context.read<DashboardState>();
      if (dashboardState.sensors.isNotEmpty) {
        final activeSensor = dashboardState.sensors.first;
        setState(() {
          _alertThreshold = activeSensor.moistureThreshold ?? 25.0;
          _syncIntervalMinutes = activeSensor.syncIntervalMinutes ?? 30;
          _moistureAlertsEnabled = _alertThreshold > 0;
        });
      }
    });
  }

  // Dispatch modified configuration to cloud server via provider
  Future<void> _saveConfigToServer() async {
    try {
      final dashboardState = context.read<DashboardState>();
      if (dashboardState.sensors.isNotEmpty) {
        final activeSensor = dashboardState.sensors.first;
        await dashboardState.updateSensorConfig(
          sensorId: activeSensor.sensorId,
          threshold: _moistureAlertsEnabled ? _alertThreshold : 0.0,
          syncInterval: _syncIntervalMinutes,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update cloud configuration: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "System Settings",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _buildSectionTitle("Monitoring & Alerts"),
          _buildSettingsGroup([
            SwitchListTile(
              secondary: const Icon(
                Icons.notifications_active_outlined,
                color: Colors.orange,
              ),
              title: const Text(
                "Moisture Alerts",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                "Get a notification when your plant needs water",
              ),
              value: _moistureAlertsEnabled,
              activeColor: Colors.blue,
              onChanged: (val) {
                setState(() => _moistureAlertsEnabled = val);
                _saveConfigToServer();
              },
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(
                Icons.shutter_speed_outlined,
                color: Colors.blue,
              ),
              title: const Text(
                "Alert Threshold",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Slider(
                value: _alertThreshold,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: Colors.blue,
                inactiveColor: Colors.grey[200],
                label: "${_alertThreshold.toStringAsFixed(0)}%",
                onChanged: _moistureAlertsEnabled
                    ? (v) => setState(() => _alertThreshold = v)
                    : null,
                onChangeEnd: (v) => _saveConfigToServer(),
              ),
              trailing: Text(
                "${_alertThreshold.toStringAsFixed(0)}%",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _moistureAlertsEnabled ? Colors.black87 : Colors.grey,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 28),

          _buildSectionTitle("Device Configuration"),
          _buildSettingsGroup([
            ListTile(
              leading: const Icon(Icons.timer_outlined, color: Colors.green),
              title: const Text(
                "Data Sync Interval",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text("Every $_syncIntervalMinutes minutes"),
              trailing: PopupMenuButton<int>(
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey[400],
                ),
                onSelected: (int newInterval) {
                  setState(() => _syncIntervalMinutes = newInterval);
                  _saveConfigToServer();
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
                  const PopupMenuItem<int>(
                    value: 5,
                    child: Text('Every 5 minutes'),
                  ),
                  const PopupMenuItem<int>(
                    value: 15,
                    child: Text('Every 15 minutes'),
                  ),
                  const PopupMenuItem<int>(
                    value: 30,
                    child: Text('Every 30 minutes'),
                  ),
                  const PopupMenuItem<int>(
                    value: 60,
                    child: Text('Every 1 hour'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.wifi_rounded, color: Colors.purple),
              title: const Text(
                "Network Status",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: const Text(
                "Connected",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 28),

          _buildSectionTitle("Danger Zone"),
          _buildSettingsGroup([
            ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.redAccent,
              ),
              title: const Text(
                "Delete All Sensors",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                "Wipe all data from the database permanently",
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: Colors.redAccent.withOpacity(0.5),
              ),
              onTap: () => _showDeleteConfirmation(context),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(
                Icons.remove_circle_outline_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                "Delete Sensor by Name/ID",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text("Remove a single operational node asset"),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: Colors.redAccent.withOpacity(0.5),
              ),
              onTap: () => _showDeleteSingleSensorDialog(context),
            ),
          ]),
          const SizedBox(height: 28),

          _buildSectionTitle("Cloud Server"),
          _buildSettingsGroup([
            ListTile(
              leading: const Icon(
                Icons.cloud_done_outlined,
                color: Colors.cyan,
              ),
              title: const Text(
                "Server Status",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text("Render Cloud Active"),
              trailing: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 36),

          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _alertThreshold = 25.0;
                  _syncIntervalMinutes = 30;
                  _moistureAlertsEnabled = true;
                });
                _saveConfigToServer();
              },
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.grey,
                size: 18,
              ),
              label: const Text(
                "Reset All Settings",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Confirm Full Purge"),
        content: const Text(
          "Are you sure you want to wipe all linked sensors? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<DashboardState>().deleteAllSensors();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("All sensors successfully cleared"),
                      backgroundColor: Colors.black87,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Wipe error: $e"),
                      backgroundColor: Colors.redAccent,
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
    String selectedType = 'sensorId';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Erase Target Node"),
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
                  if (value != null) {
                    setDialogState(() => selectedType = value);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Identify Asset By',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: selectedType == 'sensorId'
                      ? 'Enter Sensor unique ID'
                      : 'Enter Sensor Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) return;

                Navigator.pop(ctx);
                try {
                  if (selectedType == 'sensorId') {
                    await context.read<DashboardState>().deleteSensorById(
                      value,
                    );
                  } else {
                    await context.read<DashboardState>().deleteSensorByName(
                      value,
                    );
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Erase sequence completed for "$value"'),
                        backgroundColor: Colors.black87,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Target erasure failure: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                } finally {
                  controller.dispose();
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}
