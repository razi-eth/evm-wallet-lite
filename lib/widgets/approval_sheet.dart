import 'package:flutter/material.dart';

/// Bottom sheet persetujuan. Dipakai untuk SEMUA aksi signing dari dApp.
/// Tidak ada transaksi / signature yang jalan tanpa tap "Setujui" di sini.
Future<bool> showApprovalSheet(
  BuildContext context, {
  required String title,
  required String origin,
  required List<MapEntry<String, String>> details,
  String approveLabel = 'Setujui',
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Dari: $origin',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            for (final d in details) ...[
              Text(d.key,
                  style: Theme.of(context).textTheme.labelMedium),
              SelectableText(d.value),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(approveLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tolak'),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
