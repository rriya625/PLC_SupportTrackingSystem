import 'package:flutter/material.dart';

/// Give every scrollable its own visible scrollbar, including mobile and dialogs.
class PortalScrollBehavior extends MaterialScrollBehavior {
  const PortalScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      trackVisibility: true,
      thickness: 10,
      radius: const Radius.circular(5),
      child: child,
    );
  }
}
