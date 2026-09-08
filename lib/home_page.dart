import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  String selectedMode = 'auto';

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body:  Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,

        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [Text("EMS Control"), Icon(Icons.signal_cellular_alt), Text('Online')],),
          SizedBox(height: 30,),
          Center(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'auto',
                  label: Text('Auto'),
                  icon: Icon(Icons.autorenew),
                ),
                ButtonSegment(
                  value: 'grid',
                  label: Text('Grid'),
                  icon: Icon(Icons.electric_bolt),
                ),
                ButtonSegment(
                  value: 'battery',
                  label: Text('Battery'),
                  icon: Icon(Icons.battery_charging_full),
                ),
                
              ],

              selected: {selectedMode},

              onSelectionChanged: (value) {
                setState(() {
                  selectedMode = value.first;
                });
              },
              style: ButtonStyle(    backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                    (states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.green;
                  }
                  return Colors.white;
                },
              ),
              padding: WidgetStateProperty.all(const EdgeInsets.all(55))),
            ),
          ),
          SizedBox(height: 30,),
          Column(children: [Text('Battery Status'),Text('Battery Percentage: 100%'), Text('Voltage: 54.1V'),Text('Current: 0A'),
            Text('Temperature 25C')],),
          SizedBox(height: 30,),
          Column(children: [Text('PZEM Status'),Text('Grid Voltage: 120.3V'),Text('Grid Power: 39W'),
            Text('Load Power Factor: 0.99')],)
        ],
      ),
    );
  }
}