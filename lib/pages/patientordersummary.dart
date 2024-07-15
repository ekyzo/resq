import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:resq/pages/homepage.dart';

class PatientOrderSummary extends StatefulWidget {
  final String orderId;

  const PatientOrderSummary({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  _PatientOrderSummaryState createState() => _PatientOrderSummaryState();
}

class _PatientOrderSummaryState extends State<PatientOrderSummary> {
  double _rating = 0.0;
  bool _isRatingSubmitted = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _fetchOrderDetailsWithDelay(),
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
            String formattedDuration = 'N/A';

            if (startOrderTimestamp != null &&
                completedOrderTimestamp != null) {
              Duration duration = completedOrderTimestamp
                  .toDate()
                  .difference(startOrderTimestamp.toDate());
              formattedDuration = _formatDuration(duration);
            }

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
                    'Severity: $severity / 5',
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
                    child: Text(
                      'Rate the Service',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: RatingBar.builder(
                      initialRating: _rating,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
                      itemBuilder: (context, _) => Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      onRatingUpdate: (rating) {
                        setState(() {
                          _rating = rating;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 32),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        _submitRating();
                      },
                      child: Text(
                        'Submit Rating'.toUpperCase(),
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
                  SizedBox(height: 12),
                  Center(
                    child: ElevatedButton(
                      onPressed: _isRatingSubmitted
                          ? () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HomePage(),
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        'Back to Menu'.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRatingSubmitted
                            ? Color.fromARGB(255, 138, 1, 1)
                            : Colors.grey,
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
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchOrderDetailsWithDelay() async {
    await Future.delayed(Duration(seconds: 1));
    return _fetchOrderDetails();
  }

  Future<Map<String, dynamic>?> _fetchOrderDetails() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('orderHistory')
          .doc(widget.orderId)
          .get();

      if (document.exists) {
        return document.data() as Map<String, dynamic>?;
      }
    } catch (e) {
      print('Error fetching order details: $e');
    }
    return null;
  }

  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);

    String formattedDuration = '$hours hours $minutes minutes';
    return formattedDuration;
  }

  void _submitRating() async {
    try {
      await FirebaseFirestore.instance
          .collection('orderHistory')
          .doc(widget.orderId)
          .update({'rating': _rating});
      setState(() {
        _isRatingSubmitted = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rating submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit rating'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error submitting rating: $e');
    }
  }
}
