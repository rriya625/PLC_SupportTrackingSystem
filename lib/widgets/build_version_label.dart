import 'package:flutter/material.dart';
import 'package:ticket_tracker_app/constants.dart';

class BuildVersionLabel extends StatelessWidget {
  const BuildVersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final version = Constants.appBuildVersion;
    final displayVersion = version.split('-').first.replaceFirst('+', '.');
    final environment = Constants.buildEnv.toUpperCase();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Tooltip(
          message: 'Build $version ($environment)',
          child: Text(
            'v$displayVersion - $environment',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
