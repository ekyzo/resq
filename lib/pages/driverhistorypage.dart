import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:resq/pages/reportpage.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class DriverHistoryPage extends StatefulWidget {
  const DriverHistoryPage({super.key});

  @override
  State<DriverHistoryPage> createState() => _DriverHistoryPageState();
}

class _DriverHistoryPageState extends State<DriverHistoryPage> {
  final user = FirebaseAuth.instance.currentUser!;

  Stream<List<Map<String, dynamic>>> _orderHistoryStream() {
    return FirebaseFirestore.instance
        .collection('orderHistory')
        .where('driverId', isEqualTo: user.uid)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs.map((doc) {
        print('Document ID: ${doc.id}');
        print('Document Data: ${doc.data()}');
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    });
  }

  void _showOrderDetails(Map<String, dynamic> historyItem) {
    String formattedTimestamp = historyItem['timestamp'] != null
        ? DateFormat('dd/MM/yyyy (kk:mm)')
            .format((historyItem['timestamp'] as Timestamp).toDate())
        : 'N/A';
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date: $formattedTimestamp',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.0),
              Text(
                'Emergency: ${historyItem['emergencyType']}',
                style: TextStyle(fontSize: 15),
              ),
              SizedBox(height: 8.0),
              Text(
                'Description: ${historyItem['description']}',
                style: TextStyle(fontSize: 15),
              ),
              SizedBox(height: 8.0),
              Text(
                'Patient Name: ${historyItem['userName']}',
                style: TextStyle(fontSize: 15),
              ),
              SizedBox(height: 8.0),
              Text(
                'Hospital Destination: ${historyItem['selectedHospital']['name']}',
                style: TextStyle(fontSize: 15),
              ),
              SizedBox(height: 8.0),
              if (historyItem.containsKey('rating'))
                Row(
                  children: [
                    Text(
                      'Rating:',
                      style: TextStyle(fontSize: 15),
                    ),
                    SizedBox(width: 8.0),
                    RatingBarIndicator(
                      rating: historyItem['rating'] ?? 0.0,
                      itemBuilder: (context, index) => Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      itemCount: 5,
                      itemSize: 20.0,
                      direction: Axis.horizontal,
                    ),
                  ],
                ),
              SizedBox(height: 8.0),
              Text(
                'Feedback: ${historyItem['feedback'] ?? 'Not yet given'}',
                style: TextStyle(
                  fontSize: 15,
                  color: historyItem['feedback'] != null
                      ? Colors.blue
                      : Colors.black,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 138, 1, 1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: Colors.white),
        toolbarHeight: 60,
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 10.0, right: 8.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
              child: Image(
                image: AssetImage('assets/resq_logo.png'),
                width: 120,
                height: 45,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Color.fromARGB(255, 138, 1, 1),
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Padding(
              padding: const EdgeInsets.only(
                top: 15,
                left: 15,
                bottom: 15,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Order History'.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    height: 4,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ReportPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color.fromARGB(255, 138, 1, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      padding:
                          EdgeInsets.symmetric(vertical: 5, horizontal: 40),
                    ),
                    child: Text('View Report', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3), // changes position of shadow
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 20,
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _orderHistoryStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error loading order history'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No order history found'));
                  } else {
                    final orderHistory = snapshot.data!;
                    return ListView.builder(
                      itemCount: orderHistory.length,
                      itemBuilder: (context, index) {
                        final historyItem = orderHistory[index];
                        String formattedTimestamp =
                            historyItem['timestamp'] != null
                                ? DateFormat('dd/MM/yyyy (kk:mm)').format(
                                    (historyItem['timestamp'] as Timestamp)
                                        .toDate())
                                : 'N/A';

                        return GestureDetector(
                          onTap: () => _showOrderDetails(historyItem),
                          child: Card(
                            margin: EdgeInsets.all(10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            elevation: 5,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date: $formattedTimestamp',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8.0),
                                  Text(
                                    'Patient Name: ${historyItem['userName']}',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                  SizedBox(height: 8.0),
                                  Text(
                                    'Emergency: ${historyItem['emergencyType']}',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                  SizedBox(height: 8.0),
                                  if (historyItem.containsKey('rating'))
                                    Row(
                                      children: [
                                        Text(
                                          'Rating:',
                                          style: TextStyle(fontSize: 15),
                                        ),
                                        SizedBox(width: 8.0),
                                        RatingBarIndicator(
                                          rating: historyItem['rating'] ?? 0.0,
                                          itemBuilder: (context, index) => Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                          ),
                                          itemCount: 5,
                                          itemSize: 20.0,
                                          direction: Axis.horizontal,
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
