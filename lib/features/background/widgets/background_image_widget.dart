import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';

class BackgroundImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String? description;
  final Uint8List? imageData;

  const BackgroundImageWidget({
    super.key,
    this.imageUrl,
    this.description,
    this.imageData,
  });

  @override
  Widget build(BuildContext context) {
    // If imageUrl is null, empty, or a placeholder URL, show gradient
    if ((imageUrl == null ||
            imageUrl!.isEmpty ||
            imageUrl!.contains('example.com') ||
            imageUrl!.startsWith('http://example') ||
            imageUrl!.startsWith('https://example')) &&
        imageData == null) {
      // Create a themed gradient based on description
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

    // Determine image provider
    ImageProvider imageProvider;

    if (imageData != null) {
      // Use memory image if we have raw bytes
      imageProvider = MemoryImage(imageData!);
    } else if (imageUrl != null && imageUrl!.startsWith('data:image')) {
      // Handle base64 data URL
      try {
        final base64String = imageUrl!.split(',')[1];
        final bytes = base64Decode(base64String);
        imageProvider = MemoryImage(bytes);
      } catch (e) {
        // Fallback to gradient if base64 decode fails
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
    } else {
      // Use network image
      imageProvider = NetworkImage(imageUrl!);
    }

    // Use Container with DecorationImage for full-screen coverage
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
          alignment: Alignment.center,
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
