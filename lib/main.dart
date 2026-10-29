import 'package:flutter/material.dart';

// =============================================================
// EMS CONTROL - UI-ONLY DEMONSTRATION
// =============================================================
// CSUN Senior Design Project
//
// This file contains the Flutter home-screen interface only.
// It does NOT connect to MQTT, the Raspberry Pi, or any relays.
// All battery/PZEM measurements below are demonstration values.
// Buttons change their appearance but do NOT control hardware.
//
// Search this file for 'TODO' to find future integration points.
// This standalone version starts at the home screen; it does not
// include the separate login page.
// =============================================================
void main() {
  runApp(const EmsUiDemo());
}

class EmsUiDemo extends StatelessWidget {
  const EmsUiDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color csunRed = Color(0xFFD22030);

  // ===========================================================
  // TODO 1: OPERATING-MODE COMMANDS
  // ===========================================================
  // Current behavior: locally highlights Auto, Grid, or Battery.
  // Future behavior: publish the selected mode to the Raspberry Pi.
  // Original MQTT topic: relay___mode/mode_select
  // Original payloads: Auto={"mode":0}, Battery={"mode":1},
  //                    Grid={"mode":2}
  // Only send a real command once MQTT is connected. Ideally,
  // update the displayed mode using confirmed hardware feedback.
  // ===========================================================
  String selectedMode = 'auto';

  // ===========================================================
  // TODO 2: LIVE BATTERY DATA
  // ===========================================================
  // These values are EXAMPLES, not measurements.
  // Original MQTT subscription: solar/battery/#
  // Replace these demo values using received SOC, voltage,
  // current, and temperature; call setState() when they change.
  // ===========================================================
  double batteryPercentage = 75.0;
  double batteryVoltage = 12.6;
  double batteryCurrent = 5.2;
  double batteryTemperature = 27.0;

  // ===========================================================
  // TODO 3: LIVE PZEM DATA
  // ===========================================================
  // These values are EXAMPLES, not measurements.
  // Original MQTT subscription: pzem/#
  // Replace these demo values using received grid voltage,
  // grid power, and power factor; call setState() on updates.
  // ===========================================================
  double gridVoltage = 120.0;
  double gridPower = 500.0;
  double loadPowerFactor = 0.95;

  Widget statusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget statusCard(String title, List<Widget> content) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black12),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: csunRed,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              for (int i = 0; i < content.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                content[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // =========================================================
      // TODO 4: MQTT CONNECTION STATUS
      // =========================================================
      // The header currently displays 'Demo' instead of Online/
      // Offline. When MQTT is integrated, maintain connection
      // state and update the icon/text to match the real status.
      // =========================================================
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        backgroundColor: csunRed,
        elevation: 0,
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'EMS Control',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Icon(Icons.visibility, color: Colors.white, size: 28),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Demo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.black12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Operating Mode',
                        style: TextStyle(
                          color: csunRed,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'auto',
                              label: Text('Auto'),
                              icon: Icon(Icons.check),
                            ),
                            ButtonSegment<String>(
                              value: 'grid',
                              label: Text('Grid'),
                              icon: Icon(Icons.electric_bolt),
                            ),
                            ButtonSegment<String>(
                              value: 'battery',
                              label: Text('Battery'),
                              icon: Icon(Icons.battery_charging_full),
                            ),
                          ],
                          selected: {selectedMode},
                          onSelectionChanged: (Set<String> selection) {
                            setState(() {
                              selectedMode = selection.first;
                            });
                            // TODO 1: Publish the selected mode to
                            // MQTT here after checking connectivity.
                            // NO hardware command is sent here.
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color?>(
                              (states) => states.contains(WidgetState.selected)
                                  ? Colors.green
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // TODO 2: These battery fields use demo state above.
              // Layout can remain unchanged when live values arrive.
              statusCard('Battery Status', [
                statusRow(
                  'Battery Percentage',
                  '${batteryPercentage.toStringAsFixed(0)}%',
                ),
                statusRow('Voltage', '${batteryVoltage.toStringAsFixed(1)} V'),
                statusRow('Current', '${batteryCurrent.toStringAsFixed(1)} A'),
                statusRow(
                  'Temperature',
                  '${batteryTemperature.toStringAsFixed(1)}°C',
                ),
              ]),
              const SizedBox(height: 20),
              // TODO 3: These PZEM fields use demo state above.
              // Layout can remain unchanged when live values arrive.
              statusCard('PZEM Status', [
                statusRow('Grid Voltage', '${gridVoltage.toStringAsFixed(1)} V'),
                statusRow('Grid Power', '${gridPower.toStringAsFixed(1)} W'),
                statusRow(
                  'Load Power Factor',
                  loadPowerFactor.toStringAsFixed(2),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// FUTURE INTEGRATION CHECKLIST
// =============================================================
// TODO: Connect to the MQTT broker on the Raspberry Pi.
// TODO: Replace 'Demo' with actual connection status.
// TODO: Subscribe to solar/battery/# and pzem/#.
// TODO: Parse received measurements and update UI state.
// TODO: Publish mode changes to relay___mode/mode_select.
// TODO: Confirm relay behavior before connecting real hardware.
// =============================================================
