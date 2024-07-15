import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

class MyOrderForm extends StatefulWidget {
  final LatLng location;

  const MyOrderForm({super.key, required this.location});

  @override
  State<MyOrderForm> createState() => _MyOrderFormState();
}

class _MyOrderFormState extends State<MyOrderForm> {
  String? _emergencyType;
  double _severity = 1;
  final _descriptionController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser!;
  File? _selectedImage;

  Future<Map<String, dynamic>> _fetchUserDetails() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (userDoc.exists && userDoc.data() != null) {
      return userDoc.data()!;
    }
    return {};
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
          'orders/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  void _submitOrder() async {
    final userDetails = await _fetchUserDetails();

    if (userDetails.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch user details.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await _uploadImage(_selectedImage!);
    }

    final orderData = {
      'emergencyType': _emergencyType,
      'description': _descriptionController.text,
      'severity': _severity,
      'location': GeoPoint(widget.location.latitude, widget.location.longitude),
      'timestamp': Timestamp.now(),
      'userId': user.uid,
      'userName': '${userDetails['firstName']} ${userDetails['lastName']}',
      'userPhone': userDetails['phoneNumber'],
      'status': 'In Progress'
    };

    if (imageUrl != null) {
      orderData['imageUrl'] = imageUrl;
    }

    if (_emergencyType == null || _descriptionController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill in all fields.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    FirebaseFirestore.instance
        .collection('order')
        .add(orderData)
        .then((DocumentReference document) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'orderInProgress': true,
        'orderId': document.id,
      }, SetOptions(merge: true)).then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order submitted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, widget.location);
        }
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update user document: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit order: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: Colors.black),
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
                width: 160,
                height: 160,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Type of Emergency: ',
                style: TextStyle(fontSize: 16),
              ),
              DropdownButtonFormField<String>(
                value: _emergencyType,
                onChanged: (value) {
                  setState(() {
                    _emergencyType = value;
                  });
                },
                items: [
                  DropdownMenuItem(
                    value: 'Accident',
                    child: Text('Accident'),
                  ),
                  DropdownMenuItem(
                    value: 'Stroke',
                    child: Text('Stroke'),
                  ),
                  DropdownMenuItem(
                    value: 'Heart Attack',
                    child: Text('Heart Attack'),
                  ),
                  DropdownMenuItem(
                    value: 'Severe Bleeding',
                    child: Text('Severe Bleeding'),
                  ),
                  DropdownMenuItem(
                    value: 'Breathing Difficulties / Asthma',
                    child: Text('Breathing Difficulties / Asthma'),
                  ),
                  DropdownMenuItem(
                    value: 'Seizure',
                    child: Text('Seizure'),
                  ),
                  DropdownMenuItem(
                    value: 'Loss of Consciousness',
                    child: Text('Loss of Consciousness'),
                  ),
                  DropdownMenuItem(
                    value: 'Poisoning / Drug Overdose',
                    child: Text('Poisoning / Drug Overdose'),
                  ),
                  DropdownMenuItem(
                    value: 'Others',
                    child: Text('Others'),
                  ),
                ],
                decoration: InputDecoration(
                  hintText: 'Select one',
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Brief Description: ',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(
                height: 10,
              ),
              TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'Write your description here',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Severity Scale: $_severity/5.0',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
              Slider(
                thumbColor: Color.fromARGB(255, 138, 1, 1),
                value: _severity,
                min: 1,
                max: 5,
                divisions: 4,
                onChanged: (value) {
                  setState(() {
                    _severity = value;
                  });
                },
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Image Upload (Optional) :',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(
                    width: 12,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 138, 1, 1),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                    onPressed: _pickImage,
                    child: Text('Select Image'),
                  ),
                ],
              ),
              SizedBox(height: 10),
              _selectedImage != null
                  ? Image.file(
                      _selectedImage!,
                      width: 80,
                      height: 180,
                      fit: BoxFit.fitHeight,
                    )
                  : Text('No image selected.'),
              SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromARGB(255, 138, 1, 1),
                  foregroundColor: Colors.white,
                ),
                onPressed: _submitOrder,
                child: Text('Order Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
