import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionWidget extends StatelessWidget {
  final bool compact;
  final Color? textColor;

  const AppVersionWidget({
    super.key,
    this.compact = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.hasData ? snapshot.data!.version : '1.0.2';
        final buildNumber = snapshot.hasData ? snapshot.data!.buildNumber : '3';

        if (compact) {
          return Text(
            'v$version ($buildNumber)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor ?? const Color(0xFF00796B),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEAE7E2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ASH Bakery POS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D241E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version $version',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor ?? const Color(0xFF8C7E6A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Build $buildNumber',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor ?? Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Utility function to display an About Dialog with version info
void showAboutAppDialog(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFF004D40)),
            SizedBox(width: 8),
            Text(
              'About ASH POS',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 64, errorBuilder: (_, __, ___) => const Icon(Icons.cake, size: 64, color: Color(0xFF004D40))),
            const SizedBox(height: 12),
            const Text(
              'ASH Bakery POS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D241E)),
            ),
            const SizedBox(height: 4),
            Text(
              'Version ${packageInfo.version}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF00796B)),
            ),
            Text(
              'Build ${packageInfo.buildNumber}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            const Text(
              'Baking Prep & Printing Management System',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
          ),
        ],
      );
    },
  );
}
