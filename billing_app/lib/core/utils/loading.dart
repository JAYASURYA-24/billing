import 'package:flutter/material.dart';

Future<T> showLoadingWhile<T>(BuildContext context, Future<T> future) async {
  // Show a modal loading spinner
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final result = await future;
    return result;
  } finally {
    // Always close the loading spinner, even if an error happens
    Navigator.pop(context);
  }
}
