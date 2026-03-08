import 'package:flutter/material.dart';

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
}
