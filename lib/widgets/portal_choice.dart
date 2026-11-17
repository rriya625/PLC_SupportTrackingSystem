import 'package:flutter/material.dart';

Future<String?> choosePortalValue(
  BuildContext context,
  String title,
  List<Map<String, String>> choices,
) => showDialog<String>(
  context: context,
  builder: (context) {
    var search = '';
    return StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 560,
          height: MediaQuery.sizeOf(context).height * .55,
          child: Column(
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    update(() => search = value.toLowerCase()),
              ),
              Expanded(
                child: ListView(
                  children: choices
                      .where(
                        (e) => '${e['Code']} ${e['Description']}'
                            .toLowerCase()
                            .contains(search),
                      )
                      .map(
                        (e) => ListTile(
                          title: Text(e['Description'] ?? ''),
                          subtitle: Text(e['Code'] ?? ''),
                          onTap: () => Navigator.pop(context, e['Code']),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  },
);
