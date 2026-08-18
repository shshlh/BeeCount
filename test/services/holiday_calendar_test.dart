import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/services/data/holiday_calendar.dart';

void main() {
  test('周末不是交易日（调休上班日也不开市）', () {
    expect(HolidayCalendar.isTradingDay(DateTime(2026, 2, 14)), isFalse);
    expect(HolidayCalendar.isTradingDay(DateTime(2026, 8, 16)), isFalse);
  });

  test('2026 法定节假日为假日', () {
    expect(HolidayCalendar.isHoliday(DateTime(2026, 1, 1)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2026, 2, 15)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2026, 2, 23)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2026, 4, 5)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2026, 5, 1)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2026, 6, 19)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2026, 9, 25)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2026, 10, 1)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2026, 10, 7)), isTrue);
  });

  test('2027 推算节假日为假日', () {
    expect(HolidayCalendar.isHoliday(DateTime(2027, 1, 1)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2027, 2, 5)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2027, 4, 4)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2027, 5, 1)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2027, 6, 10)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2027, 9, 16)), isTrue);
    expect(HolidayCalendar.isHoliday(DateTime(2027, 10, 1)), isTrue);
  });

  test('普通工作日为交易日', () {
    expect(HolidayCalendar.isTradingDay(DateTime(2026, 8, 18)), isTrue);
    expect(HolidayCalendar.isTradingDay(DateTime(2027, 8, 18)), isTrue);
  });
}
