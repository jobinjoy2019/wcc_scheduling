import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CustomScheduleCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final Set<DateTime> selectedDates;
  final void Function(Set<DateTime>) onDaySelected;
  final Map<Color, List<DateTime>>? colorHighlights;
  final bool showLegend;
  final Map<Color, String>? legendMap;
  final void Function(DateTime)? onDayDoubleTapped;
  final void Function(DateTime)? onFocusedDayChanged;

  const CustomScheduleCalendar({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
    this.selectedDates = const {},
    this.colorHighlights,
    this.showLegend = false,
    this.legendMap,
    this.onDayDoubleTapped,
    this.onFocusedDayChanged,
  });

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _containsDate(List<DateTime> dates, DateTime day) {
    return dates.any((d) => _isSameDay(d, day));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TableCalendar(
            focusedDay: focusedDay,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            startingDayOfWeek: StartingDayOfWeek.saturday,
            selectedDayPredicate: (day) {
              return selectedDates.any((d) => _isSameDay(d, day));
            },
            onDaySelected: (selected, focused) {
              onDaySelected({selected});
              if (onFocusedDayChanged != null) {
                onFocusedDayChanged!(focused);
              }
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleTextStyle: TextStyle(color: colorScheme.onSurface),
              leftChevronIcon:
                  Icon(Icons.chevron_left, color: colorScheme.onSurface),
              rightChevronIcon:
                  Icon(Icons.chevron_right, color: colorScheme.onSurface),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle:
                  TextStyle(color: colorScheme.onSurface.withAlpha(180)),
              weekendStyle: TextStyle(color: colorScheme.error),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: colorScheme.onSurface),
              todayDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.primary,
                  width: 2,
                ),
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.secondary,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              weekendTextStyle: TextStyle(color: colorScheme.error),
              defaultDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              outsideDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focused) {
                final isSelected = selectedDates.any((d) => _isSameDay(d, day));
                final isToday = _isSameDay(day, DateTime.now());

                Color? highlightColor;
                if (!isSelected && colorHighlights != null) {
                  for (final entry in colorHighlights!.entries) {
                    final color = entry.key;
                    final dates = entry.value;
                    if (_containsDate(dates, day)) {
                      highlightColor = color;
                      break;
                    }
                  }
                }

                BoxDecoration? dayDecoration;
                TextStyle dayTextStyle;

                if (isSelected) {
                  dayDecoration = BoxDecoration(
                    color: colorScheme.secondary,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                  );
                  dayTextStyle = TextStyle(color: colorScheme.onSecondary);
                } else if (isToday) {
                  dayDecoration = BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                  );
                  dayTextStyle = TextStyle(color: colorScheme.onSurface);
                } else if (highlightColor != null) {
                  dayDecoration = BoxDecoration(
                    color: highlightColor.withAlpha(200),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                  );
                  dayTextStyle = TextStyle(color: colorScheme.onSurface);
                } else {
                  dayDecoration = const BoxDecoration(
                    shape: BoxShape.rectangle,
                  );
                  dayTextStyle = focused.month == day.month
                      ? TextStyle(color: colorScheme.onSurface)
                      : TextStyle(color: colorScheme.onSurface.withAlpha(80));

                  if (day.weekday == DateTime.saturday ||
                      day.weekday == DateTime.sunday) {
                    dayTextStyle =
                        dayTextStyle.copyWith(color: colorScheme.error);
                  }
                }

                Widget dayWidget = Container(
                  margin: const EdgeInsets.all(6),
                  decoration: dayDecoration,
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: dayTextStyle,
                  ),
                );

                return GestureDetector(
                  onDoubleTap: () {
                    if (onDayDoubleTapped != null) {
                      onDayDoubleTapped!(day);
                    }
                  },
                  child: dayWidget,
                );
              },
            ),
          ),
        ),
        if (showLegend && legendMap != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: legendMap!.entries.map((entry) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: entry.key,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.value,
                    style:
                        TextStyle(color: colorScheme.onSurface.withAlpha(180)),
                  )
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
