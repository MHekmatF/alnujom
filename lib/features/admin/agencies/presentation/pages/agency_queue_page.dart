import 'package:flutter/material.dart';

// TODO(Phase 9): replace this stub with the full AgencyQueuePage implementation.
class AgencyQueuePage extends StatelessWidget {
  const AgencyQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: _AgencyQueueAppBar(),
      body: SizedBox.shrink(),
    );
  }
}

class _AgencyQueueAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AgencyQueueAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Agency Queue'));
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
