import 'package:flutter/material.dart';
import 'package:stelliberty/clash/providers/clash_provider.dart';
import 'package:stelliberty/i18n/i18n.dart';
import 'package:stelliberty/ui/common/modern_tooltip.dart';

// 代理页面操作按钮栏
class ProxyActionBar extends StatelessWidget {
  final ClashProvider clashProvider;
  final String selectedGroupName;
  final VoidCallback onLocate;
  final int sortMode;
  final ValueChanged<int> onSortModeChanged;

  const ProxyActionBar({
    super.key,
    required this.clashProvider,
    required this.selectedGroupName,
    required this.onLocate,
    required this.sortMode,
    required this.onSortModeChanged,
  });

  void _handleTestDelays() {
    clashProvider.testGroupDelays(selectedGroupName);
  }

  void _handleSortModeChange() {
    const totalSortModes = 3;
    final nextMode = (sortMode + 1) % totalSortModes;
    onSortModeChanged(nextMode);
  }

  @override
  Widget build(BuildContext context) {
    final canTestDelays =
        !clashProvider.isLoading &&
        clashProvider.isRunning &&
        !clashProvider.isBatchTesting;
    final canLocate = !clashProvider.isLoading;

    return Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 4.0,
        bottom: 0.0,
      ),
      child: Row(
        children: [
          ModernTooltip(
            message: context.translate.proxy.testAllDelays,
            child: IconButton(
              onPressed: canTestDelays ? _handleTestDelays : null,
              icon: Icon(
                Icons.network_check,
                size: 18,
                color: clashProvider.isBatchTesting ? Colors.grey : null,
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
          ModernTooltip(
            message: context.translate.proxy.locate,
            child: IconButton(
              onPressed: canLocate ? onLocate : null,
              icon: const Icon(Icons.gps_fixed, size: 18),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
          ModernTooltip(
            message: _getSortTooltip(context, sortMode),
            child: IconButton(
              onPressed: _handleSortModeChange,
              icon: Icon(_getSortIcon(sortMode), size: 18),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSortIcon(int mode) {
    switch (mode) {
      case 0:
        return Icons.sort;
      case 1:
        return Icons.sort_by_alpha;
      case 2:
        return Icons.speed;
      default:
        return Icons.sort;
    }
  }

  String _getSortTooltip(BuildContext context, int mode) {
    switch (mode) {
      case 0:
        return context.translate.proxy.defaultSort;
      case 1:
        return context.translate.proxy.nameSort;
      case 2:
        return context.translate.proxy.delaySort;
      default:
        return context.translate.proxy.defaultSort;
    }
  }
}
