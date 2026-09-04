import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/backup_service.dart';
import '../state/library_provider.dart';
import 'settings_section.dart';

/// Settings section for exporting the whole library (books, categories,
/// reading stamps, cover presets, saved pages, name sets, and every
/// locally-stored cover/page photo they reference) to a single `.zip` file,
/// and restoring one back in. See [BackupService] for the archive format
/// and what importing does to the current library.
class BackupRestoreSection extends StatefulWidget {
  const BackupRestoreSection({super.key});

  @override
  State<BackupRestoreSection> createState() => _BackupRestoreSectionState();
}

class _BackupRestoreSectionState extends State<BackupRestoreSection> {
  bool _exporting = false;
  bool _importing = false;

  bool get _busy => _exporting || _importing;

  Future<void> _export() async {
    final t = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      final zipBytes = await BackupService.instance.exportToZipBytes();
      final now = DateTime.now();
      final stamp =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: t.exportBackup,
        fileName: 'quetzalib_backup_$stamp.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: zipBytes,
      );
      if (!mounted) return;
      if (savedPath != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.backupExported)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.backupExportFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    final t = AppLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.importBackupTitle),
        content: Text(t.importBackupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.importBackup),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _importing = true);
    try {
      final importResult = await BackupService.instance.importFromZipBytes(
        bytes,
      );
      if (!mounted) return;
      await context.read<LibraryProvider>().loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.backupImported('${importResult.bookCount}')),
        ),
      );
    } on InvalidBackupException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.invalidBackupFile)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.backupImportFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SettingsSection(
      title: t.backupSectionTitle,
      icon: Icons.inventory_2_rounded,
      children: [
        Text(
          t.backupSectionBody,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: _busy ? null : _export,
              child: _exporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.exportBackup),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _busy ? null : _import,
              child: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.importBackup),
            ),
          ],
        ),
      ],
    );
  }
}
