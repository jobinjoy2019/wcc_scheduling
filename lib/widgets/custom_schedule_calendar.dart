import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CustomScheduleCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final Set<DateTime> selectedDates;
  final void Function(Set<DateTime>) onDaySelected;
  final Map<Color, List<DateTime>>? colorHighlights;
  final bool showLegend;
  final Map<Color, String>? legendMap;
  final void Function(DateTime)? onDayDoubleTapped;
  final void Function(DateTime)? onFocusedDayChanged;
  final CalendarFormat calendarFormat;
  final void Function(CalendarFormat)? onFormatChanged;

  const CustomScheduleCalendar({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
    required this.calendarFormat,
    this.onFormatChanged,
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
            calendarFormat: calendarFormat,
            onFormatChanged: (_) {},
            shouldFillViewport: false,
            focusedDay: focusedDay,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            startingDayOfWeek: StartingDayOfWeek.saturday,
            selectedDayPredicate: (day) {
              return selectedDates.any((d) => _isSameDay(d, day));
            },
            availableCalendarFormats: const {
              CalendarFormat.month: 'Month',
              CalendarFormat.week: 'Week',
            },
            onDaySelected: (selected, focused) {
              onDaySelected({selected});
              if (onFocusedDayChanged != null) {
                onFocusedDayChanged!(focused);
              }
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              leftChevronVisible: false,
              rightChevronVisible: false,
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle:
                  TextStyle(color: colorScheme.onSurface.withAlpha(180)),
              weekendStyle: TextStyle(color: colorScheme.error),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: colorScheme.onSurface),
              todayDecoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
                color: Colors.transparent,
                border: Border.all(
                  color: colorScheme.primary,
                  width: 3,
                ),
              ),
              todayTextStyle: TextStyle(
                color: colorScheme.onSurface, // or any other contrast color
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
              headerTitleBuilder: (context, date) {
                final monthText = DateFormat.yMMMM().format(date);
                final isWeek = calendarFormat == CalendarFormat.week;
                final toggleIcon = isWeek
                    ? Icons.calendar_view_month
                    : Icons.calendar_view_week;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left arrow
                    IconButton(
                      icon: Icon(Icons.chevron_left,
                          color: colorScheme.onSurface),
                      onPressed: () {
                        onFocusedDayChanged?.call(
                          DateTime(date.year, date.month - 1, 1),
                        );
                      },
                    ),

                    // Center title
                    Text(
                      monthText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),

                    Row(
                      children: [
                        // Right arrow
                        IconButton(
                          icon: Icon(Icons.chevron_right,
                              color: colorScheme.onSurface),
                          onPressed: () {
                            onFocusedDayChanged?.call(
                              DateTime(date.year, date.month + 1, 1),
                            );
                          },
                        ),

                        // Toggle button
                        IconButton(
                          icon: Icon(toggleIcon, color: colorScheme.primary),
                          tooltip:
                              isWeek ? 'Switch to Month' : 'Switch to Week',
                          onPressed: () {
                            onFormatChanged!(
                              isWeek
                                  ? CalendarFormat.month
                                  : CalendarFormat.week,
                            );
                          },
                        )
                      ],
                    ),
                  ],
                );
              },
              defaultBuilder: (context, day, focused) {
                final isSelected = selectedDates.any((d) => _isSameDay(d, day));

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
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  margin: const EdgeInsets.all(4),
                  decoration: dayDecoration,
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: dayTextStyle,
                    textAlign: TextAlign.center,
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
