import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/dates.dart';
import '../../data/database/database.dart';
import '../../data/models/event_status.dart';
import '../../data/repositories/event_repository.dart';
import '../events/event_draft.dart';
import '../events/event_editor_sheet.dart';
import 'calendar_state.dart';
import 'event_detail_popover.dart';
import 'time_grid.dart';

class DayView extends ConsumerStatefulWidget {
  const DayView({super.key, this.day});

  final DateTime? day;

  @override
  ConsumerState<DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<DayView> {
  final _scroll = ScrollController(initialScrollOffset: kDefaultScrollOffset);

  int? _dragStartMinute;
  int? _dragCurrentMinute;

  String? _draggingId;
  int? _dragOriginalStart;
  int? _dragCurrentStart;

  DateTime get _day => dateOnly(widget.day ?? ref.read(selectedDayProvider));

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _minuteAt(double localY) => yToMinute(localY).clamp(0, 1440);

  Future<void> _openCreate({
    EventKind kind = EventKind.reminder,
    int? start,
    int? end,
  }) async {
    await showEventEditor(
      context,
      date: _day,
      initialKind: kind,
      startMinute: start,
      endMinute: end,
    );
  }

  Future<void> _complete(Event event) async {
    await ref
        .read(eventRepositoryProvider)
        .setCompleted(event.id, !event.isCompleted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final events = ref.watch(eventsForDayProvider(_day)).value ??
        const <Event>[];
    final today = dateOnly(DateTime.now());
    final isToday = _day == today;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Text(
                DateFormat.yMMMMEEEEd(locale).format(_day),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton.filledTonal(
                tooltip: l10n.newEvent,
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => _openCreate(),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('day-scroll'),
            controller: _scroll,
            child: SizedBox(
              height: kHoursInDay * kHourHeight,
              child: Stack(
                children: [
                  const Positioned.fill(child: HourGrid()),
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final minute = _minuteAt(details.localPosition.dy);
                        _openCreate(
                          kind: EventKind.reminder,
                          start: minute,
                        );
                      },
                      onVerticalDragStart: (details) {
                        setState(() {
                          _dragStartMinute =
                              _minuteAt(details.localPosition.dy);
                          _dragCurrentMinute = _dragStartMinute;
                        });
                      },
                      onVerticalDragUpdate: (details) {
                        setState(() {
                          _dragCurrentMinute =
                              _minuteAt(details.localPosition.dy);
                        });
                      },
                      onVerticalDragEnd: (_) {
                        final start = _dragStartMinute;
                        final current = _dragCurrentMinute;
                        setState(() {
                          _dragStartMinute = null;
                          _dragCurrentMinute = null;
                        });
                        if (start == null || current == null) return;
                        final selection = selectionFromDrag(start, current);
                        if (selection.end - selection.start < 5) {
                          // A tiny drag is a tap in disguise.
                          _openCreate(
                            kind: EventKind.reminder,
                            start: selection.start,
                          );
                          return;
                        }
                        _openCreate(
                          kind: EventKind.plan,
                          start: selection.start,
                          end: selection.end,
                        );
                      },
                    ),
                  ),
                  if (_dragStartMinute != null && _dragCurrentMinute != null)
                    _dragPreview(),
                  for (final event in events) ..._eventLayers(event, today),
                  if (isToday) _nowLine(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dragPreview() {
    final selection =
        selectionFromDrag(_dragStartMinute!, _dragCurrentMinute!);
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: 52,
      right: 10,
      top: minuteToY(selection.start),
      height: minuteToY(selection.end) - minuteToY(selection.start),
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.primary.withValues(alpha: .5)),
          ),
        ),
      ),
    );
  }

  List<Widget> _eventLayers(Event event, DateTime today) {
    if (event.kind == EventKind.plan.dbValue) {
      final start = event.startMinute ?? 0;
      final end = event.endMinute ?? start + 30;
      final top = minuteToY(start);
      final height = (minuteToY(end) - top).clamp(16.0, 24 * kHourHeight);
      return [
        Positioned(
          left: 52,
          right: 10,
          top: _draggingId == event.id
              ? minuteToY(_dragCurrentStart ?? start)
              : top,
          height: height,
          child: _PlanBlock(
            key: ValueKey('plan-${event.id}'),
            event: event,
            overdue: eventStatus(event, today) == EventStatus.overdue,
            onTap: () => showEventDetailPopover(context, event),
            onDragStart: () => setState(() {
              _draggingId = event.id;
              _dragOriginalStart = start;
              _dragCurrentStart = start;
            }),
            onDragUpdate: (dy) => setState(() {
              final base = _dragCurrentStart ?? start;
              _dragCurrentStart =
                  snapMinutes(base + dy.round()).clamp(0, 1430);
            }),
            onDragEnd: () async {
              final moved = _dragCurrentStart;
              setState(() {
                _draggingId = null;
                _dragCurrentStart = null;
                _dragOriginalStart = null;
              });
              if (moved == null || moved == start) return;
              final repo = ref.read(eventRepositoryProvider);
              final updated = event.copyWith(
                startMinute: Value(moved),
                endMinute: Value(moved + (end - start)),
                updatedAt: DateTime.now(),
              );
              await repo.updateEvent(updated);
            },
          ),
        ),
      ];
    }

    final start = event.startMinute ?? 0;
    return [
      Positioned(
        left: 52,
        right: 10,
        top: minuteToY(start) - 6,
        child: _ReminderCard(
          key: ValueKey('reminder-${event.id}'),
          event: event,
          overdue: eventStatus(event, today) == EventStatus.overdue,
          onComplete: () => _complete(event),
          onTap: () => showEventDetailPopover(context, event),
        ),
      ),
    ];
  }

  Widget _nowLine() {
    final now = DateTime.now();
    final y = minuteToY(now.hour * 60 + now.minute);
    return Positioned(
      left: 48,
      right: 0,
      top: y,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(height: 1, color: const Color(0xFFFF3B30)),
          ),
        ],
      ),
    );
  }
}

class _PlanBlock extends StatefulWidget {
  const _PlanBlock({
    super.key,
    required this.event,
    required this.overdue,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Event event;
  final bool overdue;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final void Function(double dy) onDragUpdate;
  final Future<void> Function() onDragEnd;

  @override
  State<_PlanBlock> createState() => _PlanBlockState();
}

class _PlanBlockState extends State<_PlanBlock> {
  double _accumulated = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final event = widget.event;
    final done = event.isCompleted;

    return GestureDetector(
      onTap: widget.onTap,
      onPanStart: (_) {
        _accumulated = 0;
        widget.onDragStart();
      },
      onPanUpdate: (details) {
        _accumulated += details.delta.dy * 60 / kHourHeight;
        if (_accumulated.abs() >= 5) {
          widget.onDragUpdate(_accumulated);
          _accumulated = 0;
        }
      },
      onPanEnd: (_) => widget.onDragEnd(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: done
              ? scheme.surfaceContainerHighest.withValues(alpha: .5)
              : scheme.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: done
                ? scheme.outlineVariant
                : scheme.primary.withValues(alpha: .45),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: done ? scheme.outline : scheme.onSurface,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              _range(event),
              style: TextStyle(
                fontSize: 9.5,
                color: widget.overdue ? scheme.error : scheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _range(Event event) {
    String fmt(int? m) => m == null
        ? '--:--'
        : DateFormat.Hm().format(DateTime(2000, 1, 1, m ~/ 60, m % 60));
    final range = '${fmt(event.startMinute)}–${fmt(event.endMinute)}';
    final status = widget.overdue
        ? ' · ${AppLocalizations.of(context).overdue}'
        : '';
    return '$range$status';
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    super.key,
    required this.event,
    required this.overdue,
    required this.onComplete,
    required this.onTap,
  });

  final Event event;
  final bool overdue;
  final VoidCallback onComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final done = event.isCompleted;
    final time = event.startMinute == null
        ? l10n.allDay
        : DateFormat.Hm().format(DateTime(
            2000, 1, 1, event.startMinute! ~/ 60, event.startMinute! % 60));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1414141E),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              key: ValueKey('complete-${event.id}'),
              visualDensity: VisualDensity.compact,
              iconSize: 17,
              icon: Icon(
                done
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: done ? scheme.primary : scheme.outline,
              ),
              onPressed: onComplete,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: done ? scheme.outline : scheme.onSurface,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              overdue ? '${l10n.overdue} · $time' : time,
              style: TextStyle(
                fontSize: 10,
                color: overdue ? scheme.error : scheme.outline,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
