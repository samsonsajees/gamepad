import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import 'dependency_manager.dart';

class DependencyScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const DependencyScreen({super.key, required this.onComplete});

  @override
  State<DependencyScreen> createState() => _DependencyScreenState();
}

class _DependencyScreenState extends State<DependencyScreen> {
  bool _checking = true;
  bool _vigemInstalled = false;
  bool _installingVigem = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final installed = await DependencyManager.checkDependencies();
    setState(() {
      _vigemInstalled = installed;
      _checking = false;
    });
  }

  Future<void> _installVigem() async {
    setState(() => _installingVigem = true);
    final success = await DependencyManager.installViGEmBus();
    if (success) {
      await _check();
    } else {
      setState(() => _installingVigem = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to install ViGEmBus.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'REQUIRED DRIVERS',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPri,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please ensure the following dependencies are set up before starting the server.',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppTheme.textDim,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            if (_checking)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
              )
            else ...[
              // ViGEmBus
              _DependencyItem(
                title: 'ViGEmBus Driver',
                description: 'Required to emulate Xbox controllers on Windows.',
                isReady: _vigemInstalled,
                isRequired: true,
                action: _vigemInstalled
                    ? null
                    : _installingVigem
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent,
                        ),
                      )
                    : TextButton(
                        onPressed: _installVigem,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accent,
                          textStyle: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('INSTALL'),
                      ),
              ),
              const SizedBox(height: 24),
              // ADB
              const _DependencyItem(
                title: 'Android Platform Tools (ADB)',
                description:
                    'Required for USB Tethering connection. Can be disabled in Settings.',
                isReady: true,
                isRequired: true,
                badgeText: 'BUNDLED',
              ),
            ],

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _vigemInstalled
                      ? AppTheme.accent
                      : AppTheme.card,
                  foregroundColor: _vigemInstalled
                      ? Colors.white
                      : AppTheme.textDim,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _vigemInstalled ? widget.onComplete : null,
                child: const Text(
                  'CONTINUE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DependencyItem extends StatelessWidget {
  final String title;
  final String description;
  final bool isReady;
  final bool isRequired;
  final String? badgeText;
  final Widget? action;

  const _DependencyItem({
    required this.title,
    required this.description,
    required this.isReady,
    required this.isRequired,
    this.badgeText,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReady
              ? AppTheme.green.withOpacity(0.3)
              : AppTheme.accent.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle_rounded : Icons.error_rounded,
            color: isReady ? AppTheme.green : AppTheme.accent,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPri,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isRequired
                            ? AppTheme.accent.withOpacity(0.1)
                            : AppTheme.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isRequired ? 'REQUIRED' : 'OPTIONAL',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: isRequired
                              ? AppTheme.accent
                              : AppTheme.textDim,
                        ),
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppTheme.textDim,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 16), action!],
        ],
      ),
    );
  }
}
