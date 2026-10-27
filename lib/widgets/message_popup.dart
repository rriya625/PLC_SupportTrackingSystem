import 'package:flutter/material.dart';

/// Keep the ticket or inbox underneath while composing a message.
Future<T?> showMessagePopup<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool tall = false,
}) => showDialog<T>(
  context: context,
  barrierDismissible: false,
  routeSettings: settings,
  builder: (context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 680,
      height: tall
          ? (MediaQuery.sizeOf(context).height - 32).clamp(0.0, 960.0)
          : (MediaQuery.sizeOf(context).height * .9).clamp(0.0, 760.0),
      child: builder(context),
    ),
  ),
);
