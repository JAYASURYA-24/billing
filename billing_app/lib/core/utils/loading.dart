import 'package:flutter/material.dart';

Future<T> showLoadingWhile<T>(BuildContext context, Future<T> future) async {
  // Show a modal loading spinner
  showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => const Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 2, 113, 192),
          ),
        ),
  );

  try {
    final result = await future;
    return result;
  } finally {
    // Always close the loading spinner, even if an error happens
    Navigator.pop(context);
  }
}

Future<T> showLoadingWhileTask<T>(
  BuildContext context,
  Future<T> Function() task,
) async {
  return showLoadingWhile(context, task());
}
