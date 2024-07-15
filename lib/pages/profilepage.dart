import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:resq/components/textbox.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser!;
  final usersCollection = FirebaseFirestore.instance.collection("users");
  File? _imageFile;

  Future<DocumentSnapshot> getUserData() async {
    return await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
  }

  Future<void> pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      await uploadImageToFirebase();
    }
  }

  Future<void> uploadImageToFirebase() async {
    if (_imageFile == null) return;

    try {
      // Retrieve old profile picture URL
      final userDoc = await usersCollection.doc(user.uid).get();
      final oldProfilePictureUrl = userDoc.data()?['profilePicture'];

      // Upload new profile picture
      final fileName = path.basename(_imageFile!.path);
      final storageRef =
          FirebaseStorage.instance.ref().child('profile_pictures/$fileName');
      await storageRef.putFile(_imageFile!);
      final newImageUrl = await storageRef.getDownloadURL();

      // Update user's profile with new profile picture URL
      await usersCollection
          .doc(user.uid)
          .update({'profilePicture': newImageUrl});

      // Delete old profile picture from Firebase Storage if it exists
      if (oldProfilePictureUrl != null &&
          oldProfilePictureUrl.startsWith('https')) {
        await FirebaseStorage.instance
            .refFromURL(oldProfilePictureUrl)
            .delete();
      }

      setState(() {});
    } catch (e) {
      print('Error uploading image: $e');
    }
  }

  Future<void> editField(String field) async {
    String newValue = "";
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          "Edit " + field,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          autofocus: true,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter new $field",
            hintStyle: TextStyle(color: Colors.grey),
          ),
          onChanged: (value) {
            newValue = value;
          },
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () => Navigator.of(context).pop(newValue),
          ),
        ],
      ),
    );

    if (newValue.isNotEmpty) {
      await usersCollection.doc(user.uid).update({field: newValue});
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
      body: FutureBuilder<DocumentSnapshot>(
        future: getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('No data available'));
          } else {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final profilePicture =
                userData['profilePicture'] ?? 'assets/profile.png';
            return ListView(
              children: [
                const SizedBox(
                  height: 30,
                ),
                Center(
                  child: GestureDetector(
                    onTap: pickImage,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : profilePicture.startsWith('assets/')
                              ? AssetImage(profilePicture)
                              : NetworkImage(profilePicture) as ImageProvider,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  user.email!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(
                  height: 50,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 25.0),
                  child: Text(
                    'Profile Details',
                    style: TextStyle(
                        color: Colors.grey[600],
                        decoration: TextDecoration.underline),
                  ),
                ),
                MyTextBox(
                  text: userData['firstName'] ?? '',
                  sectionName: 'First Name',
                  onPressed: () => editField('firstName'),
                ),
                MyTextBox(
                  text: userData['lastName'] ?? '',
                  sectionName: 'Last Name',
                  onPressed: () => editField('lastName'),
                ),
                MyTextBox(
                  text: userData['phoneNumber'] ?? '',
                  sectionName: 'Phone Number',
                  onPressed: () => editField('phoneNumber'),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
