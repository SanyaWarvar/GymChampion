import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../router.dart';
import 'app_update_service.dart';

/// Shows update UI on the root navigator (survives splash → login/home).
abstract final class AppUpdatePrompt {
  static bool _dialogOpen = false;
  static bool _autoCheckDone = false;

  /// Once per process after auth leaves loading.
  static void maybeAutoCheck() {
    if (_autoCheckDone || !AppUpdateService.isSupported) return;
    if (rootNavigatorKey.currentContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => maybeAutoCheck());
      return;
    }
    _autoCheckDone = true;
    unawaited(check(silent: true));
  }

  /// [silent]: network/errors and "up to date" stay quiet.
  static Future<void> check({bool silent = false}) async {
    if (!AppUpdateService.isSupported) {
      if (!silent) _snack('Обновления доступны только на Android');
      return;
    }

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final service = AppUpdateService();
    try {
      final update = await service.checkForUpdate();
      if (!context.mounted) return;
      if (update == null) {
        if (!silent) _snack('Уже последняя версия');
        return;
      }
      await _showUpdateDialog(context, service, update);
    } catch (_) {
      if (!silent && context.mounted) {
        _snack('Не удалось проверить обновления');
      }
    }
  }

  static Future<void> _showUpdateDialog(
    BuildContext context,
    AppUpdateService service,
    AvailableUpdate update,
  ) async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (ctx) => _UpdateDialog(service: service, update: update),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  static void _snack(String message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.service,
    required this.update,
  });

  final AppUpdateService service;
  final AvailableUpdate update;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  bool _busy = false;
  String? _error;
  File? _downloaded;

  Future<void> _downloadAndInstall() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = _downloaded == null ? 0 : 1;
    });
    try {
      final file = _downloaded ??
          await widget.service.downloadApk(
            widget.update,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      _downloaded = file;
      final status = await widget.service.installApk(file);
      if (!mounted) return;
      if (status == 'opened_settings') {
        setState(() {
          _busy = false;
          _error =
              'Разрешите установку из этого приложения в настройках, затем нажмите снова.';
        });
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Не удалось скачать или установить обновление';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.update.versionLabel;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Доступна новая версия'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Скачается APK с GitHub. Android попросит подтвердить установку.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (_progress != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress,
              color: AppColors.amber,
              backgroundColor: AppColors.background,
            ),
            const SizedBox(height: 6),
            Text(
              '${((_progress ?? 0) * 100).round()}%',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Позже'),
        ),
        FilledButton(
          onPressed: _busy ? null : _downloadAndInstall,
          child: Text(
            _busy
                ? (_downloaded == null ? 'Скачивание…' : 'Установка…')
                : (_downloaded == null
                    ? 'Скачать и установить'
                    : 'Установить'),
          ),
        ),
      ],
    );
  }
}
