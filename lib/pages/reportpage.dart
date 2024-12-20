import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);

  @override
  _ReportPageState createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final user = FirebaseAuth.instance.currentUser!;
  String _selectedPeriod = 'last7days';

  int last7DaysCount = 0;
  int lastMonthCount = 0;
  int lastYearCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchOrderCounts();
  }

  Future<void> _fetchOrderCounts() async {
    last7DaysCount = await _fetchOrderCountByTimePeriod('last7days');
    lastMonthCount = await _fetchOrderCountByTimePeriod('lastMonth');
    lastYearCount = await _fetchOrderCountByTimePeriod('lastYear');

    setState(() {});
  }

  Future<int> _fetchOrderCountByTimePeriod(String period) async {
    DateTime now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'last7days':
        startDate = now.subtract(Duration(days: 7));
        break;
      case 'last30days': // Adjusted for last 30 days
        startDate = now.subtract(Duration(days: 30));
        break;
      case 'lastMonth':
        // This needs to show the previous month from today's date, not just the last 30 days
        startDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'lastYear':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('orderHistory')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print('Error fetching orders: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchOrdersByTimePeriod(
      String period) async {
    DateTime now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'last7days':
        startDate = now.subtract(Duration(days: 7));
        break;
      case 'last30days': // Adjusted for last 30 days
        startDate = now.subtract(Duration(days: 30));
        break;
      case 'lastMonth':
        // This needs to show the previous month from today's date, not just the last 30 days
        startDate = now.subtract(Duration(days: 30));
        break;
      case 'lastYear':
        startDate = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        startDate = DateTime(now.year, now.month, now.day);
    }

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('orderHistory')
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('driverId',
              isEqualTo: user.uid) // Filter by current user's uid
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error fetching orders: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 138, 1, 1),
      body: Column(
        children: [
          Container(
            color: Color.fromARGB(255, 138, 1, 1),
            padding: EdgeInsets.only(top: 60, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Order Reports'.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPeriodButton(
                          'Last 7 Days', 'last7days', last7DaysCount),
                      _buildPeriodButton(
                          'Last Month', 'lastMonth', lastMonthCount),
                      _buildPeriodButton(
                          'Last Year', 'lastYear', lastYearCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: Column(
                children: [
                  Expanded(child: _buildReportList(_selectedPeriod)),
                  SizedBox(height: 20),
                  Expanded(child: _buildLineGraph(_selectedPeriod)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String text, String period, int count) {
    bool isSelected = _selectedPeriod == period;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedPeriod = period;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.white : Colors.red[800],
          foregroundColor:
              isSelected ? Color.fromARGB(255, 138, 1, 1) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.0),
          ),
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 45),
        ),
        child: Column(
          children: [
            Text(
              text,
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '$count orders',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportList(String period) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchOrdersByTimePeriod(period),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error loading orders'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No orders found'));
        } else {
          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              DateTime orderTime = order['timestamp'].toDate();

              // Check if 'completedOrder' field exists and is not null
              DateTime? finishTime;
              if (order.containsKey('completedOrder') &&
                  order['completedOrder'] != null) {
                finishTime = order['completedOrder'].toDate();
              }

              Duration? duration;
              String durationString = 'N/A';
              if (finishTime != null) {
                duration = finishTime.difference(orderTime);
                durationString =
                    '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
              }

              return Card(
                margin: EdgeInsets.all(5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                elevation: 5,
                child: ExpansionTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date: ${DateFormat('yyyy-MM-dd').format(orderTime)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Patient Name: ${order['userName']}',
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Driver Name: ${order['driverName']}',
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Emergency Type: ${order['emergencyType']}',
                        style: TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    ListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Severity: ${order['severity']}',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Description: ${order['description']}',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Order Time: ${DateFormat('kk:mm').format(orderTime)}',
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                          if (finishTime != null) ...[
                            Text(
                              'Order Finish: ${DateFormat('kk:mm').format(finishTime)}',
                              style: TextStyle(
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Duration: $durationString',
                              style: TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildLineGraph(String period) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchOrdersByTimePeriod(period),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error loading orders'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No orders found'));
        } else {
          final orders = snapshot.data!;
          Map<String, int> orderCounts = {};

          for (var order in orders) {
            DateTime orderTime = order['timestamp'].toDate();
            String formattedDate;
            if (period == 'last7days' || period == 'lastMonth') {
              formattedDate = DateFormat('dd').format(orderTime);
            } else {
              formattedDate = DateFormat('MM/yy').format(orderTime);
            }

            orderCounts[formattedDate] = (orderCounts[formattedDate] ?? 0) + 1;
          }

          List<FlSpot> spots = [];
          int index = 0;

          for (var entry in orderCounts.entries) {
            spots.add(FlSpot(index.toDouble(), entry.value.toDouble()));
            index++;
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    barWidth: 4,
                    color: Colors.blue,
                  ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                      sideTitles: SideTitles(
                    showTitles: false,
                  )),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= orderCounts.keys.length) {
                          return const Text('');
                        }
                        return Text(orderCounts.keys.elementAt(index));
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
