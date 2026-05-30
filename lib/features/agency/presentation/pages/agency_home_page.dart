import 'package:flutter/material.dart';

// TODO(Phase 8): replace this stub with the full AgencyHomePage implementation.
class AgencyHomePage extends StatelessWidget {
  const AgencyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: _AgencyAppBar(),
      body: SizedBox.shrink(),
    );
  }
}

class _AgencyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AgencyAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Agency'));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
