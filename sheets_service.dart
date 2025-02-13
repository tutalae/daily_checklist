import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';

/// Paste your **Google Service Account JSON** below
const _credentials = r'''

''';

/// **Google Spreadsheet ID**
const _spreadsheetId = "1wlQHhw_vdMKA38hu_ydhnIFAVSCQuZV5Dh79eOrq9Vk";

class SheetsService {
  late GSheets gsheets;
  late Spreadsheet ss;
  Worksheet? jobsSheet;
  Worksheet? assignJobsSheet;

  SheetsService() {
    gsheets = GSheets(_credentials);
  }

  /// **Initialize Google Sheets**
  Future<void> init() async {
    try {
      ss = await gsheets.spreadsheet(_spreadsheetId);
      jobsSheet = ss.worksheetByTitle('Daily Jobs') ??
          await ss.addWorksheet('Daily Jobs');
      assignJobsSheet = ss.worksheetByTitle('Assign Jobs');

      if (jobsSheet != null) {
        final existingRows = await jobsSheet!.values.allRows() ?? [];
        if (existingRows.isEmpty || existingRows[0][0] != "Date") {
          await jobsSheet!.values
              .insertRow(1, ["Date", "Shift", "Task", "Status", "Completed Time"]);
        }
      }
    } catch (e) {
      print("❌ Error initializing Google Sheets: $e");
      throw Exception(
          "Failed to initialize Sheets. Please check credentials or network.");
    }
  }

  /// **Generate Daily Job List Based on Assign Jobs Tab**
  Future<void> createDailyJobList() async {
    if (jobsSheet == null || assignJobsSheet == null) return;

    try {
      final today = getTodayDate();
      final rows = await assignJobsSheet!.values.allRows() ?? [];

      if (rows.length <= 1) return;

      bool jobsExist = await _checkIfJobsExistForToday();
      if (jobsExist) {
        print("✅ Jobs already exist for today. Skipping creation.");
        return;
      }

      for (var row in rows.skip(1)) {
        if (row.length >= 3) {
          final shift = row[0];
          final task = row[1];
          final repeat = row[2].toLowerCase();

          if (shouldTaskBeAdded(repeat)) {
            await jobsSheet!.values.appendRow([today, shift, task, "⏳ Undone", ""]);
          }
        }
      }

      print("✅ Jobs created for $today.");
    } catch (e) {
      print("❌ Error creating daily job list: $e");
    }
  }

  /// **Check if a task should be added based on its repeat schedule**
  bool shouldTaskBeAdded(String repeat) {
    final today = DateTime.now();
    final weekdayMap = {
      "monday": DateTime.monday,
      "tuesday": DateTime.tuesday,
      "wednesday": DateTime.wednesday,
      "thursday": DateTime.thursday,
      "friday": DateTime.friday,
      "saturday": DateTime.saturday,
      "sunday": DateTime.sunday
    };

    String normalizedRepeat = repeat.toLowerCase().trim();

    if (normalizedRepeat == "every day") return true;
    if (weekdayMap.containsKey(normalizedRepeat) &&
        today.weekday == weekdayMap[normalizedRepeat]) {
      return true;
    }
    if (normalizedRepeat == "every even day" && today.day % 2 == 0) {
      return true;
    }
    if (normalizedRepeat == "every odd day" && today.day % 2 != 0) {
      return true;
    }
    if (normalizedRepeat == "weekdays" &&
        today.weekday >= DateTime.tuesday &&
        today.weekday <= DateTime.saturday) { // Corrected: Sunday to Saturday
      return true;
    }
    if (normalizedRepeat == "weekends" &&
        (today.weekday == DateTime.saturday || // Corrected: Monday to Saturday
            today.weekday == DateTime.sunday)) { // Corrected: Monday to Sunday
      return true;
    }
    return false;
  }

  Future<void> markJobAsDone(String shift, String task) async {
    if (jobsSheet == null) return;

    final rows = await jobsSheet!.values.allRows() ?? [];
    for (int i = 1; i < rows.length; i++) {
      if (rows[i].length >= 3 &&
          rows[i][1] == shift &&
          rows[i][2] == task &&
          rows[i][3] == "⏳ Undone") {
        String completionTime = getCurrentDateTime();

        await jobsSheet!.values
            .insertRow(i + 1, [rows[i][0], shift, task, "✅ Done", completionTime]);
        print(
            "✅ Job marked as done: $task in shift: $shift at $completionTime");
        return;
      }
    }
  }

  String formatDate(String dateValue) {
    if (dateValue.toLowerCase() == "date") {
      return dateValue; // Header row
    }

    try {
      // 1. Try parsing as a DateTime (handles ISO 8601, etc.)
      try {
        DateTime parsedDate = DateTime.parse(dateValue);
        return DateFormat('yyyy-MM-dd').format(parsedDate); // Format to yyyy-MM-dd
      } catch (e) {
        // Ignore the error here, try the next method
      }

      // 2. Try parsing as a Google Sheets serial date (number)
      if (RegExp(r'^\d+(\.\d+)?$').hasMatch(dateValue)) {
        double serialDays = double.parse(dateValue);
        DateTime convertedDate = DateTime(1899, 12, 30)
            .add(Duration(milliseconds: (serialDays * 86400000).round()));
        return DateFormat('yyyy-MM-dd').format(convertedDate); // Format to yyyy-MM-dd
      }

      // 3. If all else fails, return the original value (for debugging)
      print("❌ Date format not recognized: $dateValue");
      return dateValue; // Or throw an exception if you prefer
    } catch (e) {
      print("❌ Error formatting date: $e, Value: $dateValue");
      return dateValue;
    }
  }

  Future<bool> _checkIfJobsExistForToday() async {
    if (jobsSheet == null) return false;
    final today = getTodayDate();
    final existingRows = await jobsSheet!.values.allRows() ?? [];

    print("Checking for existing jobs for today: $today");
    print("Number of rows in jobsSheet: ${existingRows.length}");

    bool jobsExist = existingRows.any((row) {
      if (row.isEmpty || row.length < 1) return false; // Handle empty rows

      String formattedDate = formatDate(row[0]);
      bool rowMatches = formattedDate == today; // Direct string comparison

      print("Row: $row, Formatted Date: $formattedDate, Matches: $rowMatches");
      return rowMatches;
    });

    print("Jobs exist for today: $jobsExist");
    return jobsExist;
  }

  /// **Gets today's date**
  String getTodayDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// **Gets current timestamp**
  String getCurrentDateTime() => DateTime.now().toIso8601String();
}