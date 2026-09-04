import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/app_update_info.dart';
import '../services/update_service.dart';
import 'settings_section.dart';

/// Native: the "check for updates / download / install" section that used
/// to live directly in `SettingsScreen`, unchanged — just moved out so its
/// `dart:io`-based [UpdateService] (APK download + install) stays out of
/// the web build, which has no equivalent concept.
///
/// Downloading and installing are two separate buttons on purpose: the
/// install step is the one that fails (permission denied, user cancels the
/// system installer, signature conflict), and re-downloading a whole APK
/// just to retry it is wasted data. Once the APK is in the cache the
/// section offers "install" until the update is actually installed.
class AppUpdateSection extends StatefulWidget {
  const AppUpdateSection({super.key});

  @override
  State<AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends State<AppUpdateSection> {
  final _updateService = UpdateService();

  bool _checkingUpdate = false;
  String? _updateStatus;
  String? _currentVersion;
  AppUpdateInfo? _availableUpdate;
  bool _downloading = false;
  double _downloadProgress = 0;

  /// The APK already sitting in the update cache, if any — what lets a
  /// failed install be retried without downloading again.
  File? _downloadedApk;
  bool _installing = false;

  bool get _busy => _checkingUpdate || _downloading || _installing;

  Future<void> _checkForUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateStatus = null;
      _availableUpdate = null;
      _downloadedApk = null;
    });
    final t = AppLocalizations.of(context);
    try {
      final current = await _updateService.currentVersion();
      final update = await _updateService.checkForUpdate();
      // A previous session may have downloaded this same build already.
      final cached =
          update == null ? null : await _updateService.downloadedApk(update);
      if (!mounted) return;
      setState(() {
        _currentVersion = current;
        _availableUpdate = update;
        _downloadedApk = cached;
        _updateStatus = update == null
            ? t.upToDate(current)
            : cached != null
                ? t.readyToInstall(update.version)
                : t.updateAvailable(update.version);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _updateStatus = t.couldNotCheckForUpdates('$e'));
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  Future<void> _download() async {
    final update = _availableUpdate;
    if (update == null) return;
    final t = AppLocalizations.of(context);
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
      _downloadedApk = null;
    });
    try {
      final file = await _updateService.download(
        update,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _downloadedApk = file;
        _updateStatus = t.readyToInstall(update.version);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _updateStatus = t.downloadFailed('$e'));
        _showSnackBar(t.downloadFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _install() async {
    final apk = _downloadedApk;
    final update = _availableUpdate;
    if (apk == null || update == null) return;
    final t = AppLocalizations.of(context);

    // The cache is temporary storage; Android may have reclaimed it since
    // the download.
    if (!await apk.exists()) {
      if (!mounted) return;
      setState(() {
        _downloadedApk = null;
        _updateStatus = t.downloadedFileMissing;
      });
      return;
    }

    setState(() => _installing = true);
    try {
      await _updateService.install(apk);
      // On success Android replaces this process, so there's nothing to
      // report here — but if it lingers, leave the file in place so the
      // user can retry.
    } catch (e) {
      if (mounted) {
        // Deliberately keeps _downloadedApk, so "install" stays offered.
        setState(() => _updateStatus = t.installFailed('$e'));
        _showSnackBar(t.installFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final update = _availableUpdate;
    final downloaded = _downloadedApk != null;
    return SettingsSection(
      title: t.appUpdateSectionTitle,
      icon: Icons.system_update_rounded,
      children: [
        Text(
          t.appUpdateSectionBody,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : _checkForUpdate,
              child: _checkingUpdate
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.checkForUpdates),
            ),
            if (update != null) ...[
              if (downloaded)
                FilledButton(
                  onPressed: _busy ? null : _install,
                  child: Text(_installing ? t.installing : t.installUpdate),
                )
              else
                FilledButton(
                  onPressed: _busy ? null : _download,
                  child: Text(
                    _downloading
                        ? t.downloading(
                            (_downloadProgress * 100).round().toString())
                        : t.downloadUpdate,
                  ),
                ),
              // A re-download is still available for the rare case where
              // the cached APK itself is the problem (corrupt file).
              if (downloaded)
                TextButton(
                  onPressed: _busy ? null : _download,
                  child: Text(t.downloadAgain),
                ),
            ],
          ],
        ),
        if (_updateStatus != null) ...[
          const SizedBox(height: 12),
          Text(_updateStatus!),
        ],
        if (_downloading) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _downloadProgress > 0 ? _downloadProgress : null,
          ),
        ],
        if (update?.releaseNotes.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          Text(
            update!.releaseNotes,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_currentVersion != null) ...[
          const SizedBox(height: 12),
          Text(
            t.currentVersion(_currentVersion!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
