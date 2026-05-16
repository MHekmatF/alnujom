import 'package:flutter/material.dart';

class RoleEditorPage extends StatelessWidget {
  const RoleEditorPage({required this.roleId, super.key});

  final String roleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Role editor')),
      body: Center(child: Text('Role editor placeholder: $roleId')),
    );
  }
}
