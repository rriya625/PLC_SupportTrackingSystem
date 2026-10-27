import 'package:flutter/material.dart';

class PortalLoading extends StatelessWidget {
  const PortalLoading({super.key, this.message = 'Loading...'});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(message)),
      ],
    ),
  );
}

Future<T> withPortalLoading<T>(
  BuildContext context,
  String message,
  Future<T> Function() action,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Dialog(child: PortalLoading(message: message)),
    ),
  );
  navigator.push(route);
  try {
    return await action();
  } finally {
    if (route.isActive) navigator.removeRoute(route);
  }
}
