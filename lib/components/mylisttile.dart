// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';

class MyListTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final void Function()? onTap;

  const MyListTile(
      {super.key, required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.black,
          size: 32.0,
        ),
        onTap: onTap,
        title: Text(
          text,
          style: TextStyle(
            color: Colors.black,
            letterSpacing: 4.0,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
