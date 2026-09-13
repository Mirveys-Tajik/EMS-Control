import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ---------------------------------------------------------
  // MQTT SETTINGS
  // ---------------------------------------------------------

  // CHANGE THIS to the IP address of the PROJECT Raspberry Pi.
  static const String mqttBroker = '192.168.1.34';

  static const int mqttPort = 1883;

  late MqttServerClient client;

  bool mqttConnected = false;

  // ---------------------------------------------------------
  // EMS STATE VARIABLES
  // ---------------------------------------------------------

  String selectedMode = 'auto';

  double batteryPercentage = 0;
  double batteryVoltage = 0;
  double batteryCurrent = 0;
  double batteryTemperature = 0;

  double gridVoltage = 0;
  double gridPower = 0;
  double loadPowerFactor = 0;

  // Primary application accent color.
  static const Color csunRed = Color(0xFFD22030);

  // ---------------------------------------------------------
  // START MQTT WHEN APP STARTS
  // ---------------------------------------------------------

  @override
  void initState() {
    super.initState();

    connectToMqtt();
  }

  // ---------------------------------------------------------
  // MQTT CONNECTION
  // ---------------------------------------------------------

  Future<void> connectToMqtt() async {
    final clientId =
        'ems_flutter_${DateTime.now().millisecondsSinceEpoch}';

    client = MqttServerClient(
      mqttBroker,
      clientId,
    );

    client.port = mqttPort;

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
      print('Connecting to MQTT broker...');

      await client.connect();
    } catch (e) {
      print('MQTT connection failed: $e');

      client.disconnect();

      return;
    }

    if (client.connectionStatus?.state ==
        MqttConnectionState.connected) {
      print('MQTT connected');

      listenForMqttMessages();
    } else {
      print(
        'MQTT connection failed: '
            '${client.connectionStatus}',
      );

      client.disconnect();
    }
  }

  // ---------------------------------------------------------
  // MQTT CONNECTED
  // ---------------------------------------------------------

  void onMqttConnected() {
    print('Connected to MQTT broker');

    if (mounted) {
      setState(() {
        mqttConnected = true;
      });
    }

    // Subscribe to battery information.
    client.subscribe(
      'solar/battery/#',
      MqttQos.atMostOnce,
    );

    // Subscribe to PZEM information.
    client.subscribe(
      'pzem/#',
      MqttQos.atMostOnce,
    );
  }

  // ---------------------------------------------------------
  // MQTT DISCONNECTED
  // ---------------------------------------------------------

  void onMqttDisconnected() {
    print('Disconnected from MQTT broker');

    if (mounted) {
      setState(() {
        mqttConnected = false;
      });
    }
  }

  // ---------------------------------------------------------
  // LISTEN FOR MQTT MESSAGES
  // ---------------------------------------------------------

  void listenForMqttMessages() {
    client.updates?.listen(
          (
          List<MqttReceivedMessage<MqttMessage?>> messages,
          ) {
        final message = messages[0];

        final topic = message.topic;

        final publishMessage =
        message.payload as MqttPublishMessage;

        final payload =
        MqttPublishPayload.bytesToStringAsString(
          publishMessage.payload.message,
        );

        print('MQTT Topic: $topic');
        print('MQTT Message: $payload');

        handleMqttMessage(
          topic,
          payload,
        );
      },
    );
  }

  // ---------------------------------------------------------
  // PROCESS MQTT DATA
  // ---------------------------------------------------------

  void handleMqttMessage(
      String topic,
      String message,
      ) {
    try {
      final dynamic decoded = jsonDecode(message);

      if (decoded is! Map<String, dynamic>) {
        print('MQTT message is not JSON object');

        return;
      }

      final Map<String, dynamic> data = decoded;

      if (!mounted) {
        return;
      }

      setState(() {
        // ---------------------------------------------------
        // BATTERY DATA
        // ---------------------------------------------------

        if (topic.startsWith('solar/battery/')) {
          batteryPercentage = getNumber(
            data,
            [
              'soc',
              'SOC',
              'percentage',
              'batteryPercentage',
            ],
            batteryPercentage,
          );

          batteryVoltage = getNumber(
            data,
            [
              'voltage',
              'Voltage',
              'batteryVoltage',
            ],
            batteryVoltage,
          );

          batteryCurrent = getNumber(
            data,
            [
              'current',
              'Current',
              'batteryCurrent',
            ],
            batteryCurrent,
          );

          batteryTemperature = getNumber(
            data,
            [
              'temperature',
              'Temperature',
              'temp',
              'batteryTemperature',
            ],
            batteryTemperature,
          );
        }

        // ---------------------------------------------------
        // PZEM DATA
        // ---------------------------------------------------

        if (topic.startsWith('pzem/')) {
          gridVoltage = getNumber(
            data,
            [
              'voltage',
              'Voltage',
              'gridVoltage',
            ],
            gridVoltage,
          );

          gridPower = getNumber(
            data,
            [
              'power',
              'Power',
              'gridPower',
            ],
            gridPower,
          );

          loadPowerFactor = getNumber(
            data,
            [
              'powerFactor',
              'power_factor',
              'pf',
              'PowerFactor',
            ],
            loadPowerFactor,
          );
        }
      });
    } catch (e) {
      print('Error processing MQTT message: $e');
    }
  }

  // ---------------------------------------------------------
  // HELPER FOR GETTING NUMBERS FROM JSON
  // ---------------------------------------------------------

  double getNumber(
      Map<String, dynamic> data,
      List<String> possibleNames,
      double oldValue,
      ) {
    for (final name in possibleNames) {
      if (data[name] != null) {
        final value =
        double.tryParse(data[name].toString());

        if (value != null) {
          return value;
        }
      }
    }

    return oldValue;
  }

  // ---------------------------------------------------------
  // SEND OPERATING MODE TO PI
  // ---------------------------------------------------------

  void sendModeCommand(String mode) {
    if (!mqttConnected) {
      print('Cannot send command. MQTT is offline.');

      return;
    }

    int modeNumber;

    switch (mode) {
      case 'battery':
        modeNumber = 1;
        break;

      case 'grid':
        modeNumber = 2;
        break;

      case 'auto':
      default:
        modeNumber = 0;
        break;
    }

    final payload = jsonEncode({
      'mode': modeNumber,
    });

    final builder = MqttClientPayloadBuilder();

    builder.addString(payload);

    client.publishMessage(
      'relay___mode/mode_select',
      MqttQos.atMostOnce,
      builder.payload!,
    );

    print(
      'Mode command sent: '
          '$mode -> $payload',
    );
  }

  // ---------------------------------------------------------
  // CLEAN UP MQTT WHEN APP CLOSES
  // ---------------------------------------------------------

  @override
  void dispose() {
    client.disconnect();

    super.dispose();
  }

  // ---------------------------------------------------------
  // USER INTERFACE
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // -----------------------------------------------------
      // HEADER
      // -----------------------------------------------------

      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 100,
        backgroundColor: csunRed,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
          ),
          child: Row(
            children: [
              const Expanded(
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

              Icon(
                Icons.signal_cellular_alt,
                color:
                mqttConnected
                    ? Colors.white
                    : Colors.white54,
                size: 28,
              ),

              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    mqttConnected
                        ? 'Online'
                        : 'Offline',
                    style: const TextStyle(
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

      // -----------------------------------------------------
      // BODY
      // -----------------------------------------------------

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            children: [
              // ------------------------------------------------
              // OPERATING MODE
              // ------------------------------------------------

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                  side: const BorderSide(
                    color: Colors.black12,
                  ),
                ),
                child: Padding(
                  padding:
                  const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Operating Mode',
                        style: TextStyle(
                          color: csunRed,
                          fontSize: 20,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      Center(
                        child:
                        SegmentedButton<
                            String
                        >(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'auto',
                              label:
                              Text('Auto'),
                              icon: Icon(
                                Icons.check,
                              ),
                            ),

                            ButtonSegment<String>(
                              value: 'grid',
                              label:
                              Text('Grid'),
                              icon: Icon(
                                Icons
                                    .electric_bolt,
                              ),
                            ),

                            ButtonSegment<String>(
                              value: 'battery',
                              label:
                              Text(
                                'Battery',
                              ),
                              icon: Icon(
                                Icons
                                    .battery_charging_full,
                              ),
                            ),
                          ],

                          selected: <String>{
                            selectedMode,
                          },

                          onSelectionChanged:
                              (
                              Set<String>
                              value,
                              ) {
                            final newMode =
                                value.first;

                            setState(() {
                              selectedMode =
                                  newMode;
                            });

                            sendModeCommand(
                              newMode,
                            );
                          },

                          style: ButtonStyle(
                            backgroundColor:
                            WidgetStateProperty
                                .resolveWith<
                                Color?
                            >(
                                  (
                                  states,
                                  ) {
                                if (states
                                    .contains(
                                  WidgetState
                                      .selected,
                                )) {
                                  return Colors
                                      .green;
                                }

                                return Colors
                                    .white;
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ------------------------------------------------
              // BATTERY STATUS
              // ------------------------------------------------

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                  side: const BorderSide(
                    color: Colors.black12,
                  ),
                ),

                child: SizedBox(
                  width: double.infinity,

                  child: Padding(
                    padding:
                    const EdgeInsets.all(20),

                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Battery Status',
                          style: TextStyle(
                            color: csunRed,
                            fontSize: 20,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,

                          children: [
                            const Text(
                              'Battery Percentage',
                            ),

                            Text(
                              '${batteryPercentage.toStringAsFixed(0)}%',
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,

                          children: [
                            const Text(
                              'Voltage',
                            ),

                            Text(
                              '${batteryVoltage.toStringAsFixed(1)} V',
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,

                          children: [
                            const Text(
                              'Current',
                            ),

                            Text(
                              '${batteryCurrent.toStringAsFixed(1)} A',
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,

                          children: [
                            const Text(
                              'Temperature',
                            ),

                            Text(
                              '${batteryTemperature.toStringAsFixed(1)}°C',
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ------------------------------------------------
              // PZEM STATUS
              // ------------------------------------------------

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                  side: const BorderSide(
                    color: Colors.black12,
                  ),
                ),

                child: SizedBox(
                  width: double.infinity,

                  child: Padding(
                    padding:
                    const EdgeInsets.all(20),

                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'PZEM Status',
                          style: TextStyle(
                            color: csunRed,
                            fontSize: 20,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,

                          children: [
                            const Text(
                              'Grid Voltage',
                            ),

                            Text(
                              '${gridVoltage.toStringAsFixed(1)} V',
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,

                          children: [
                            const Text(
                              'Grid Power',
                            ),

                            Text(
                              '${gridPower.toStringAsFixed(1)} W',
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .spaceBetween,

                          children: [
                            const Text(
                              'Load Power Factor',
                            ),

                            Text(
                              loadPowerFactor
                                  .toStringAsFixed(
                                2,
                              ),
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}