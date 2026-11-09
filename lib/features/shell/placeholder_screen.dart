import 'package:flutter/material.dart';

/// Temporary scaffolding. Each screen is replaced in its own stage.
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title: not built yet',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
