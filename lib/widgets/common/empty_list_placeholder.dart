import 'package:flutter/material.dart';

class EmptyListPlaceholder extends StatelessWidget {
  final String message;

  const EmptyListPlaceholder({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message, textAlign: TextAlign.center));
  }
}
