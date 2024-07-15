import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);

  @override
  _ReportPageState createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final user = FirebaseAuth.instance.currentUser!;
  String _selectedPeriod = 'today';

  int todayCount = 0;
  int last7DaysCount = 0;
  int lastMonthCount = 0;
  int lastYearCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchOrderCounts();
  }

  Future<void> _fetchOrderCounts() async {
    todayCount = await _fetchOrderCountByTimePeriod('today');
    last7DaysCount = await _fetchOrderCountByTimePeriod('last7days');
    lastMonthCount = await _fetchOrderCountByTimePeriod('lastMonth');
    lastYearCount = await _fetchOrderCountByTimePeriod('lastYear');

    setState(() {});
  }

  Future<int> _fetchOrderCountByTimePeriod(String period) async {
    DateTime now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'last7days':
        startDate = now.subtract(Duration(days: 7));
        break;
      case 'lastMonth':
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
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'last7days':
        startDate = now.subtract(Duration(days: 7));
        break;
      case 'lastMonth':
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
          .orderBy('timestamp',
              descending: true) // Add this line to sort by time
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
                      _buildPeriodButton('Today', 'today', todayCount),
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
              child: _buildReportList(_selectedPeriod),
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
}
