import 'package:flutter/material.dart';

/// Phase 17 — stub FavoritesPage.
///
/// Replaced by the full composition in Sub-Phase F (T033). The [AppBar] title
/// is a placeholder — the ARB key `favorites_page_title` lands in Sub-Phase G
/// and the full widget tree lands in Sub-Phase F.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
      ),
    );
  }
}
