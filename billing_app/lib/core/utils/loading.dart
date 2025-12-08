import 'package:flutter/material.dart';

Future<T> showLoadingWhile<T>(BuildContext context, Future<T> future) async {
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
    Navigator.pop(context);
  }
}

Future<T> showLoadingWhileTask<T>(
  BuildContext context,
  Future<T> Function() task,
) async {
  return showLoadingWhile(context, task());
}

Future<T> showLoadingWhilepdf<T>(
  BuildContext context,
  Future<T> Function() futureCallback,
) async {
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
    final result = await futureCallback();
    return result;
  } finally {
    Navigator.pop(context);
  }
}
