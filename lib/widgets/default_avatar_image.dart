import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/default_avatar.dart';

class DefaultAvatarImage extends StatelessWidget {
  const DefaultAvatarImage({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Image.memory(
        base64Decode(defaultAvatarBase64),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(
              Icons.person,
              size: 50,
              color: Colors.grey[600],
            ),
          );
        },
      ),
    );
  }
}