import 'package:flutter/material.dart';

class BackgroundImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String? description;

  const BackgroundImageWidget({
    super.key,
    this.imageUrl,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      // Default gradient background
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(imageUrl!),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        // Add a semi-transparent overlay to ensure UI elements are readable
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
        ),
      ),
    );
  }
}
