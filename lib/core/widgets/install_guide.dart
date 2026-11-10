import 'package:flutter/material.dart';

import '../platform/platform_services.dart';
import '../theme/app_theme.dart';

/// Tries the browser's own install prompt. When the browser does not offer
/// one (iPhone, an in-app browser, already dismissed) shows step-by-step help.
Future<void> installOrGuide(BuildContext context) async {
  if (canInstallApp()) {
    await promptInstallApp();
    return;
  }
  if (!context.mounted) return;
  await showInstallGuide(context);
}

Future<void> showInstallGuide(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _InstallGuideDialog(),
  );
}

class _InstallGuideDialog extends StatelessWidget {
  const _InstallGuideDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.install_mobile_outlined, color: AppColors.teal),
          SizedBox(width: 10),
          Expanded(child: Text('Install on your phone')),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Steps(
              title: 'Android (Chrome)',
              steps: [
                'Open this page in the Google Chrome app, not inside '
                    'WhatsApp, Gmail or Telegram.',
                'Tap the three dots at the top right.',
                'Tap "Install app" or "Add to Home screen".',
                'Tap Install when asked.',
              ],
            ),
            SizedBox(height: 12),
            _Steps(
              title: 'iPhone (Safari)',
              steps: [
                'Open this page in Safari.',
                'Tap the Share button.',
                'Tap "Add to Home Screen", then Add.',
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Opened this link from WhatsApp or Telegram? Tap the three dots '
              'and choose "Open in Chrome" first. Those in-app browsers cannot '
              'install apps.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.teal,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${i + 1}. ${steps[i]}'),
            ),
        ],
      ),
    );
  }
}
