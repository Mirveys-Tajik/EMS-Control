import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'about_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ------------------------------------------------------------
  // HIVE MQ SETTINGS
  // ------------------------------------------------------------

  static const String mqttBroker =
      'ba37807526404d90b709b31aaac053a2.s1.eu.hivemq.cloud';

  static const int mqttPort = 8883;

  static const String mqttUsername = 'ems_pi5';

  static const String mqttPassword = 'ece493Fall';

  late MqttServerClient client;

  bool mqttConnected = false;

  // ------------------------------------------------------------
  // EMS STATE VARIABLES
  // ------------------------------------------------------------

  // This represents the last mode confirmed through this app.
  String selectedMode = 'auto';

  // Battery/BMS
  double batteryPercentage = 0;
  double batteryVoltage = 0;
  double batteryCurrent = 0;
  double batteryTemperature = 0;

  // PZEM Load
  double loadVoltage = 0;
  double loadCurrent = 0;
  double loadPower = 0;
  double loadPowerFactor = 0;

  @override
  void initState() {
    super.initState();
    connectToMqtt();
  }

  // ------------------------------------------------------------
  // MQTT CONNECTION
  // ------------------------------------------------------------

  Future<void> connectToMqtt() async {
    final String clientId =
        'ems_flutter_${DateTime.now().millisecondsSinceEpoch}';

    client = MqttServerClient(mqttBroker, clientId);

    client.port = mqttPort;
    client.secure = true;
    client.keepAlivePeriod = 20;
    client.logging(on: false);
    client.autoReconnect = true;

    client.onConnected = onMqttConnected;
    client.onDisconnected = onMqttDisconnected;

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    try {
      print('Connecting to HiveMQ Cloud...');

      await client.connect(
        mqttUsername,
        mqttPassword,
      );

      if (client.connectionStatus?.state ==
          MqttConnectionState.connected) {
        print('HiveMQ Cloud connection successful.');
      } else {
        print(
          'HiveMQ connection failed: '
              '${client.connectionStatus}',
        );

        client.disconnect();
      }
    } catch (e) {
      print('HiveMQ connection error: $e');
      client.disconnect();
    }
  }

  // ------------------------------------------------------------
  // MQTT CONNECTED
  // ------------------------------------------------------------

  void onMqttConnected() {
    print('Connected to HiveMQ Cloud.');

    if (mounted) {
      setState(() {
        mqttConnected = true;
      });
    }

    client.subscribe(
      'solar/battery/#',
      MqttQos.atMostOnce,
    );

    client.subscribe(
      'pzem/#',
      MqttQos.atMostOnce,
    );

    client.subscribe(
      'ems/pi/status',
      MqttQos.atMostOnce,
    );

    print('Subscribed to MQTT topics.');

    client.updates?.listen(
          (List<MqttReceivedMessage<MqttMessage>> messages) {
        if (messages.isEmpty) {
          return;
        }

        final MqttPublishMessage message =
        messages[0].payload as MqttPublishMessage;

        final String payload =
        MqttPublishPayload.bytesToStringAsString(
          message.payload.message,
        );

        final String topic = messages[0].topic;

        print('MQTT Topic: $topic');
        print('MQTT Message: $payload');

        if (topic == 'ems/pi/status') {
          print('Pi status received: $payload');
          return;
        }

        processMqttMessage(topic, payload);
      },
    );
  }

  // ------------------------------------------------------------
  // MQTT DISCONNECTED
  // ------------------------------------------------------------

  void onMqttDisconnected() {
    print('Disconnected from HiveMQ Cloud.');

    if (mounted) {
      setState(() {
        mqttConnected = false;
      });
    }
  }

  // ------------------------------------------------------------
  // PROCESS RECEIVED MQTT DATA
  // ------------------------------------------------------------

  void processMqttMessage(String topic, String payload) {
    try {
      final dynamic decoded = jsonDecode(payload);

      if (decoded is! Map<String, dynamic>) {
        print('MQTT payload was not a JSON object.');
        return;
      }

      final Map<String, dynamic> data = decoded;

      if (topic.startsWith('solar/battery/')) {
        updateBatteryData(data);
      } else if (topic.startsWith('pzem/')) {
        updatePzemData(data);
      }
    } catch (e) {
      print('Error processing MQTT message: $e');
    }
  }

  // ------------------------------------------------------------
  // BATTERY DATA
  // ------------------------------------------------------------

  void updateBatteryData(Map<String, dynamic> data) {
    if (!mounted) {
      return;
    }

    setState(() {
      batteryPercentage = _readNumber(
        data,
        [
          'percentage',
          'battery_percentage',
          'soc',
          'SOC',
        ],
        batteryPercentage,
      );

      batteryVoltage = _readNumber(
        data,
        [
          'voltage',
          'battery_voltage',
          'Battery_Voltage',
        ],
        batteryVoltage,
      );

      batteryCurrent = _readNumber(
        data,
        [
          'current',
          'battery_current',
          'Battery_Current',
        ],
        batteryCurrent,
      );

      batteryTemperature = _readNumber(
        data,
        [
          'temperature',
          'battery_temperature',
          'Battery_Temperature',
          'temp',
        ],
        batteryTemperature,
      );
    });
  }

  // ------------------------------------------------------------
  // PZEM LOAD DATA
  // ------------------------------------------------------------

  void updatePzemData(Map<String, dynamic> data) {
    if (!mounted) {
      return;
    }

    setState(() {
      loadVoltage = _readNumber(
        data,
        ['Load voltage'],
        loadVoltage,
      );

      loadCurrent = _readNumber(
        data,
        ['Load amperage'],
        loadCurrent,
      );

      loadPower = _readNumber(
        data,
        ['Load power'],
        loadPower,
      );

      loadPowerFactor = _readNumber(
        data,
        ['Load powerFactor'],
        loadPowerFactor,
      );
    });
  }

  // ------------------------------------------------------------
  // JSON NUMBER HELPER
  // ------------------------------------------------------------

  double _readNumber(
      Map<String, dynamic> data,
      List<String> keys,
      double oldValue,
      ) {
    for (final String key in keys) {
      if (data.containsKey(key)) {
        final dynamic value = data[key];

        if (value is num) {
          return value.toDouble();
        }

        if (value is String) {
          final double? parsed = double.tryParse(value);

          if (parsed != null) {
            return parsed;
          }
        }
      }
    }

    return oldValue;
  }

  // ------------------------------------------------------------
  // REQUEST MODE CHANGE
  // ------------------------------------------------------------

  void requestModeChange(String mode) {
    if (mode == selectedMode) {
      return;
    }

    if (!mqttConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot change operating mode while MQTT is offline.',
          ),
        ),
      );
      return;
    }

    showModeConfirmation(mode);
  }

  // ------------------------------------------------------------
  // MODE CHANGE CONFIRMATION
  // ------------------------------------------------------------

  void showModeConfirmation(String mode) {
    String modeName;

    // This switch only determines the name shown
    // in the confirmation window.
    switch (mode) {
      case 'grid':
        modeName = 'Grid';
        break;

      case 'battery':
        modeName = 'Battery';
        break;

      case 'auto':
      default:
        modeName = 'Auto';
        break;
    }

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Change Operating Mode?',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  'You are about to change the EMS operating mode '
                      'to $modeName Mode.',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'WARNING: Changing the operating mode may switch '
                      'power sources and operate system relays. '
                      'Confirm that it is safe to change modes before continuing.',
                  style: TextStyle(
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                        },
                        child: const Text('Cancel'),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);

                          // MQTT command is sent only after confirmation.
                          changeMode(mode);
                        },
                        icon: const Icon(
                          Icons.warning_amber_rounded,
                        ),
                        label: const Text(
                          'Confirm Change',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // SEND CONFIRMED EMS OPERATING MODE
  // ------------------------------------------------------------

  void changeMode(String mode) {
    if (!mqttConnected) {
      print('Cannot change mode: MQTT is offline.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mode change failed because MQTT is offline.',
            ),
          ),
        );
      }

      return;
    }

    final MqttClientPayloadBuilder builder =
    MqttClientPayloadBuilder();

    builder.addString(mode);

    client.publishMessage(
      'ems/control/mode',
      MqttQos.atLeastOnce,
      builder.payload!,
    );

    setState(() {
      selectedMode = mode;
    });

    print(
      'Published mode $mode to ems/control/mode',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Operating mode changed to ${mode.toUpperCase()}.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ------------------------------------------------------------
  // UI HELPERS
  // ------------------------------------------------------------

  Widget statusRow(
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionCard({
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(
        bottom: 18,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.blueGrey[800],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,

        title: const Text(
          'EMS Control',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          Icon(
            mqttConnected
                ? Icons.cloud_done
                : Icons.cloud_off,
            color: mqttConnected
                ? Colors.greenAccent
                : Colors.redAccent,
          ),

          const SizedBox(width: 8),

          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: mqttConnected
                    ? Colors.green
                    : Colors.red,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                mqttConnected
                    ? 'Online'
                    : 'Offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --------------------------------------------------
            // OPERATING MODE
            // --------------------------------------------------

            sectionCard(
              title: 'Operating Mode',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: 'auto',
                          label: Text('Auto'),
                          icon: Icon(Icons.settings_suggest),
                        ),
                        ButtonSegment<String>(
                          value: 'grid',
                          label: Text('Grid'),
                          icon: Icon(Icons.bolt),
                        ),
                        ButtonSegment<String>(
                          value: 'battery',
                          label: Text('Battery'),
                          icon: Icon(Icons.battery_full),
                        ),
                      ],

                      selected: {
                        selectedMode,
                      },

                      style: ButtonStyle(
                        backgroundColor:
                        WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                            if (states.contains(
                              WidgetState.selected,
                            )) {
                              return Colors.green.shade100;
                            }

                            return null;
                          },
                        ),

                        foregroundColor:
                        WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                            if (states.contains(
                              WidgetState.selected,
                            )) {
                              return Colors.green.shade900;
                            }

                            return null;
                          },
                        ),
                      ),

                      onSelectionChanged:
                          (Set<String> selection) {
                        if (selection.isNotEmpty) {
                          requestModeChange(
                            selection.first,
                          );
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Text(
                        'Selected Mode: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        selectedMode.toUpperCase(),
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --------------------------------------------------
            // BATTERY STATUS
            // --------------------------------------------------

            sectionCard(
              title: 'Battery Status',
              child: Column(
                children: [
                  statusRow(
                    'Battery Percentage',
                    '${batteryPercentage.toStringAsFixed(0)}%',
                  ),
                  statusRow(
                    'Voltage',
                    '${batteryVoltage.toStringAsFixed(1)} V',
                  ),
                  statusRow(
                    'Current',
                    '${batteryCurrent.toStringAsFixed(1)} A',
                  ),
                  statusRow(
                    'Temperature',
                    '${batteryTemperature.toStringAsFixed(1)}°C',
                  ),
                ],
              ),
            ),

            // --------------------------------------------------
            // PZEM LOAD STATUS
            // --------------------------------------------------

            sectionCard(
              title: 'PZEM Status',
              child: Column(
                children: [
                  statusRow(
                    'Load Voltage',
                    '${loadVoltage.toStringAsFixed(1)} V',
                  ),
                  statusRow(
                    'Load Current',
                    '${loadCurrent.toStringAsFixed(2)} A',
                  ),
                  statusRow(
                    'Load Power',
                    '${loadPower.toStringAsFixed(1)} W',
                  ),
                  statusRow(
                    'Load Power Factor',
                    loadPowerFactor.toStringAsFixed(2),
                  ),
                ],
              ),
            ),
// ======================================================
// ABOUT US PAGE NAVIGATION
// ======================================================

const SizedBox(height: 12),

Center(
  child: OutlinedButton.icon(
    icon: const Icon(Icons.info_outline),
    label: const Text('About Us'),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AboutPage(),
        ),
      );
    },
  ),
),
            
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CLEANUP
  // ------------------------------------------------------------

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }
}
