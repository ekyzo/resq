import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final user = FirebaseAuth.instance.currentUser!;

  Future<List<Map<String, dynamic>>> _fetchOrderHistory() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('orderHistory')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Error fetching order history: $e');
      return [];
    }
  }

  void _showFeedbackForm(String orderId) {
    final TextEditingController feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.4,
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Feedback',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
                  ),
                ),
                SizedBox(height: 10.0),
                Expanded(
                  child: TextFormField(
                    controller: feedbackController,
                    maxLines: null,
                    expands: true,
                    decoration: InputDecoration(
                      hintText: 'Write your feedback here',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(height: 16.0),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 138, 1, 1),
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    SizedBox(width: 14.0),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 138, 1, 1),
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Save'),
                        onPressed: () async {
                          // Save feedback to Firestore
                          try {
                            await FirebaseFirestore.instance
                                .collection('orderHistory')
                                .doc(orderId)
                                .update({
                              'feedback': feedbackController.text,
                            });
                            Navigator.of(context).pop();
                            setState(
                                () {}); // Refresh the page to show the updated feedback
                          } catch (e) {
                            print('Error saving feedback: $e');
                          }
                        },
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

  void _showOrderDetails(Map<String, dynamic> historyItem) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String formattedTimestamp = historyItem['timestamp'] != null
            ? DateFormat('kk:mm (dd/MM/yyyy)')
                .format((historyItem['timestamp'] as Timestamp).toDate())
            : 'N/A';

        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.0),
                  Text('Date: $formattedTimestamp',
                      style: TextStyle(fontSize: 15)),
                  SizedBox(height: 8.0),
                  Text('Emergency: ${historyItem['emergencyType']}',
                      style: TextStyle(fontSize: 15)),
                  SizedBox(height: 8.0),
                  Text('Description: ${historyItem['description']}',
                      style: TextStyle(fontSize: 15)),
                  SizedBox(height: 8.0),
                  Text('Staff Name: ${historyItem['driverName']}',
                      style: TextStyle(fontSize: 15)),
                  SizedBox(height: 8.0),
                  if (historyItem.containsKey('rating'))
                    Row(
                      children: [
                        Text('Rating:', style: TextStyle(fontSize: 15)),
                        SizedBox(width: 8.0),
                        RatingBarIndicator(
                          rating: historyItem['rating'],
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
                  if (historyItem.containsKey('feedback'))
                    Text(
                      'Feedback: ${historyItem['feedback']}',
                      style: TextStyle(fontSize: 15, color: Colors.blue),
                    ),
                  SizedBox(height: 16.0),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 138, 1, 1),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showFeedbackForm(historyItem['id']);
                    },
                    child: Text('Give Feedback'),
                  ),
                ],
              ),
            ),
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
            padding: EdgeInsets.symmetric(
              vertical: 15,
            ),
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
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchOrderHistory(),
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
                                ? DateFormat('kk:mm (dd/MM/yyyy)').format(
                                    (historyItem['timestamp'] as Timestamp)
                                        .toDate())
                                : 'N/A';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              margin: EdgeInsets.all(10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              elevation: 5,
                              child: InkWell(
                                onTap: () {
                                  _showOrderDetails(historyItem);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        'Staff Name: ${historyItem['driverName']}',
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
                                              rating: historyItem['rating'],
                                              itemBuilder: (context, index) =>
                                                  Icon(
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
                            ),
                          ],
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
