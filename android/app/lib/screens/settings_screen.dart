import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Servers'),
            subtitle: const Text('Manage backend connections'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.servers),
          ),
        ],
      ),
    );
  }
}
