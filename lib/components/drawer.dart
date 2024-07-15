// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:resq/components/mylisttile.dart';

class MyDrawer extends StatelessWidget {
  final void Function()? onHistory;
  final void Function()? onProfile;
  final void Function()? onSignOut;
  final void Function()? onHomePage;
  const MyDrawer({
    super.key,
    required this.onHistory,
    required this.onProfile,
    required this.onSignOut,
    required this.onHomePage,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              //header
              DrawerHeader(
                child: Image(
                  image: AssetImage('assets/resq_logo.png'),
                ),
              ),

              //list tile
              MyListTile(
                icon: Icons.home,
                text: 'HOME',
                onTap: onHomePage,
              ),

              SizedBox(
                height: 5,
              ),

              //history
              MyListTile(
                icon: Icons.history,
                text: 'HISTORY',
                onTap: onHistory,
              ),

              SizedBox(
                height: 5,
              ),

              //Profile
              MyListTile(
                icon: Icons.person,
                text: 'PROFILE',
                onTap: onProfile,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: MyListTile(
              icon: Icons.logout,
              text: 'LOG OUT',
              onTap: onSignOut,
            ),
          ),
        ],
      ),
    );
  }
}
