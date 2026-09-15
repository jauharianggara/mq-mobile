import 'package:flutter/material.dart';

/// Status badge utk semua modul — konsisten warna.
class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const StatusBadge({super.key, required this.status, this.fontSize = 11});

  Color get _color {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'PASSED':
      case 'PUBLISHED':
      case 'COMPLETED':
      case 'READY':
      case 'SYSTEM_VERIFIED':
      case 'VERIFIED':
        return const Color(0xFF22C55E);
      case 'PENDING':
      case 'PENDING_VERIFICATION':
      case 'IN_REVIEW':
      case 'PUBLISH_REQUESTED':
      case 'UPLOADING':
      case 'DRAFT':
      case 'SCHEDULED':
        return const Color(0xFFF59E0B);
      case 'REJECTED':
      case 'SUSPENDED':
      case 'FAILED':
      case 'DEAD':
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      case 'REVISION':
      case 'EXPIRED':
      case 'PAYMENT_EXPIRED':
      case 'REVIEWED':
        return const Color(0xFF8B5CF6);
      case 'REQUESTED':
      case 'WAITING_CONFIRM':
        return const Color(0xFF0EA5E9);
      case 'CONFIRMED':
        return const Color(0xFF16A34A);
      case 'DECLINED':
      case 'CANCELED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// KPI kartu utk Home screen.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state sederhana.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String? message;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    this.message,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  })  : assert(message != null || title != null, 'isi message atau title');

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title ?? message ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
            if (subtitle == null && message != null && title != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
