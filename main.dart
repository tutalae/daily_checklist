import 'package:flutter/material.dart';
import 'sheets_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sheetsService = SheetsService();
  await sheetsService.init();
  await sheetsService.createDailyJobList(); // Ensure this method exists in sheets_service.dart
  runApp(MyApp(sheetsService));
}

class MyApp extends StatelessWidget {
  final SheetsService sheetsService;
  MyApp(this.sheetsService);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChecklistScreen(sheetsService),
    );
  }
}

class ChecklistScreen extends StatefulWidget {
  final SheetsService sheetsService;
  ChecklistScreen(this.sheetsService);

  @override
  _ChecklistScreenState createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  Map<String, List<Map<String, dynamic>>> jobsByShift = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadJobs();
  }

  void loadJobs() async {
    setState(() => isLoading = true);

    if (widget.sheetsService.jobsSheet == null) {
      print("❌ Jobs sheet is not initialized.");
      return;
    }

    List<List<String>> data =
        await widget.sheetsService.jobsSheet!.values.allRows() ?? [];
    Map<String, List<Map<String, dynamic>>> groupedJobs = {};

    DateTime today = DateTime.now();
    String todayStr =
        "${today.year}-${today.month}-${today.day}"; // YYYY-MM-DD format

    for (var row in data.skip(1)) {
      if (row.isNotEmpty && row.length >= 4) {
        final shift = row[1];
        final task = row[2];
        final status = row[3];
        final time =
            row.length > 4 ? widget.sheetsService.formatDate(row[4]) : "";

        // Convert timestamp to date for comparison
        DateTime? jobDate;
        if (time.isNotEmpty) {
          try {
            jobDate = DateTime.parse(time);
          } catch (e) {
            jobDate = null;
          }
        }

        // Only add jobs that are undone OR were completed today
        if (status == "⏳ Undone" ||
            (jobDate != null &&
                "${jobDate.year}-${jobDate.month}-${jobDate.day}" ==
                    todayStr)) {
          groupedJobs[shift] ??= [];
          groupedJobs[shift]!.add({
            "task": task,
            "status": status,
            "time": time,
          });
        }
      }
    }

    setState(() {
      jobsByShift = groupedJobs;
      isLoading = false;
    });
  }

  void toggleJobStatus(String shift, int index) async {
    if (jobsByShift[shift]![index]["status"] == "⏳ Undone") {
      await widget.sheetsService
          .markJobAsDone(shift, jobsByShift[shift]![index]["task"]);
      await Future.delayed(Duration(seconds: 2)); // Wait for Sheets update
      loadJobs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Daily Checklist")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: jobsByShift.keys.map((shift) {
                return ExpansionTile(
                  title: Text(shift,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  children: jobsByShift[shift]!.map((job) {
                    int jobIndex = jobsByShift[shift]!.indexOf(job);
                    return ListTile(
                      title: Text(job["task"]),
                      subtitle: Text("Status: ${job["status"]}"),
                      trailing: job["status"] == "✅ Done"
                          ? Text(
                              "✔ ${widget.sheetsService.formatDate(job["time"])}",
                              style: TextStyle(color: Colors.green))
                          : ElevatedButton(
                              onPressed: () => toggleJobStatus(shift, jobIndex),
                              child: Text("Mark Done"),
                            ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
    );
  }
}
