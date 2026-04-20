import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Widget buildCircleButton(String title, IconData icon) {
  return Column(
    children: [
      ElevatedButton(
        onPressed: () {
          print("$title button clicked!");
        },
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(25),
          backgroundColor: Colors.blueGrey[700],
          elevation: 10,
        ),
        child: Icon(icon, size: 35, color: Colors.white),
      ),
      const SizedBox(height: 10),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String helpertxt;
  final IconData icon;
  final String helperStyle;
  final bool obscureText;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.helpertxt,
    required this.icon,
    required this.helperStyle,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.indigo),
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        helperText: helpertxt,
        helperStyle: const TextStyle(color: CupertinoColors.white),
        fillColor: Colors.white.withOpacity(0.8),
      ),
    );
  }
}
