import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resq/pages/homepage.dart';

class OrderSummary extends StatelessWidget {
  final String orderId;

  const OrderSummary({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: FutureBuilder<Map<String, dynamic>?>(
          future:
              Future.delayed(Duration(seconds: 1), () => _fetchOrderDetails()),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error fetching order details'));
            } else if (!snapshot.hasData || snapshot.data == null) {
              return Center(child: Text('Order not found'));
            }

            Map<String, dynamic> orderData = snapshot.data!;
            String status = orderData['status'];
            String hospitalName = orderData['selectedHospital']['name'];
            String patientName = orderData['userName'];
            String emergency = orderData['emergencyType'];
            double severity = orderData['severity'];
            String description = orderData['description'];
            String driverName = orderData['driverName'];
            String driverPhone = orderData['driverPhone'];

            Timestamp? startOrderTimestamp = orderData['timestamp'];
            Timestamp? completedOrderTimestamp = orderData['completedOrder'];

            if (startOrderTimestamp != null &&
                completedOrderTimestamp != null) {
              Duration duration = completedOrderTimestamp
                  .toDate()
                  .difference(startOrderTimestamp.toDate());
              String formattedDuration = _formatDuration(duration);

              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Text(
                          'Order Summary'.toUpperCase(),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Hospital Destination: $hospitalName',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 12),
                    Center(
                      child: Text(
                        '$status'.toUpperCase(),
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    SizedBox(height: 12),
                    Divider(
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Patient Name: $patientName',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Emergency Type: $emergency',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Emergency Description: $description',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Severity: $severity' + ' ' + '/ 5',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Divider(
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Driver Name: $driverName',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Driver Phone: $driverPhone',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Duration: $formattedDuration',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 32),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HomePage(),
                            ),
                          );
                        },
                        child: Text(
                          'Back to Menu'.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 138, 1, 1),
                          padding: EdgeInsets.symmetric(
                            horizontal: 75,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return Center(child: Text('Order times not available'));
            }
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchOrderDetails() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('orderHistory')
          .doc(orderId)
          .get();

      if (document.exists) {
        return document.data() as Map<String, dynamic>?;
      } else {
        print('Document does not exist');
      }
    } catch (e) {
      print('Error fetching order details: $e');
      if (e is FirebaseException && e.code == 'permission-denied') {
        print('Permission denied');
        // Handle permission denial appropriately, e.g., show a message to the user
      }
    }
    return null;
  }

  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);

    String formattedDuration = '$hours hours $minutes minutes';
    return formattedDuration;
  }
}
