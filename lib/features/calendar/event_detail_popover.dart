import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/dates.dart';
import '../../data/database/database.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../events/event_editor_sheet.dart';

Future<void> showEventDetailPopover(BuildContext context, Event event) {
  return showDialog<void>(
    context: context,
    builder: (context) => EventDetailPopover(event: event),
  );
}

class EventDetailPopover extends ConsumerWidget {
  const EventDetailPopover({super.key, required this.event});

  final Event event;

  String _timeLabel(BuildContext context) {
    final start = event.startMinute;
    final end = event.endMinute;
    String fmt(int m) =>
        DateFormat.Hm().format(DateTime(2000, 1, 1, m ~/ 60, m % 60));
    if (start == null) return AppLocalizations.of(context).allDay;
    if (end == null) return fmt(start);
    return '${fmt(start)}–${fmt(end)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final repo = ref.read(eventRepositoryProvider);
    final navigator = Navigator.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${DateFormat.yMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(event.date)} · ${_timeLabel(context)}',
                style: TextStyle(fontSize: 11.5, color: scheme.outline),
              ),
              if (event.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(event.note,
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 8),
              _Action(
                icon: event.isCompleted
                    ? Icons.radio_button_unchecked
                    : Icons.check_circle_outline,
                label: l10n.done,
                onTap: () async {
                  await repo.setCompleted(event.id, !event.isCompleted);
                  final updated = await repo.getById(event.id);
                  if (updated != null) {
                    ref.read(eventNotifierSyncProvider).afterCompletion(updated);
                  }
                  navigator.pop();
                },
              ),
              _Action(
                icon: Icons.edit_outlined,
                label: l10n.edit,
                onTap: () {
                  navigator.pop();
                  showEventEditor(navigator.context, existing: event);
                },
              ),
              _Action(
                icon: Icons.event_repeat_outlined,
                label: l10n.reschedule,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: navigator.context,
                    initialDate: event.date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  await repo.reschedule(event.id, dateOnly(picked));
                  final updated = await repo.getById(event.id);
                  if (updated != null) {
                    ref.read(eventNotifierSyncProvider).afterUpdate(updated);
                  }
                  navigator.pop();
                },
              ),
              _Action(
                icon: Icons.delete_outline,
                label: l10n.delete,
                color: scheme.error,
                onTap: () async {
                  await repo.softDelete(event.id);
                  ref.read(eventNotifierSyncProvider).afterDelete(event);
                  navigator.pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: color ?? Theme.of(context).colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}
