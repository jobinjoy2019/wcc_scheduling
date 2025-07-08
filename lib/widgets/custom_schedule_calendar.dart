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
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3D),
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
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleTextStyle: TextStyle(color: Colors.white),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.white70),
              weekendStyle: TextStyle(color: Colors.redAccent),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: Colors.white),
              todayDecoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blueAccent,
                  width: 2,
                ),
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              weekendTextStyle: TextStyle(color: Colors.red),
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
                  dayDecoration = const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  );
                  dayTextStyle = const TextStyle(color: Colors.white);
                } else if (isToday) {
                  dayDecoration = BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                  );
                  dayTextStyle = const TextStyle(color: Colors.white);
                } else if (highlightColor != null) {
                  dayDecoration = BoxDecoration(
                    color: highlightColor,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                  );
                  dayTextStyle = const TextStyle(color: Colors.white);
                } else {
                  dayDecoration = const BoxDecoration(
                    shape: BoxShape.rectangle,
                  );
                  dayTextStyle = focused.month == day.month
                      ? const TextStyle(color: Colors.white)
                      : const TextStyle(color: Colors.white30);

                  if (day.weekday == DateTime.saturday ||
                      day.weekday == DateTime.sunday) {
                    dayTextStyle = dayTextStyle.copyWith(color: Colors.red);
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
                    color: entry.key,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.value,
                    style: const TextStyle(color: Colors.white70),
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
