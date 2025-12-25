import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotifyService.init();
  runApp(const HomeExpenseApp());
}

class HomeExpenseApp extends StatelessWidget {
  const HomeExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Home Expense',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const Dashboard(),
    );
  }
}

// NOTIFICATION SERVICE
class NotifyService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);
  }

  static Future showMilkAlert(double total) async {
    const android = AndroidNotificationDetails(
      'milk_channel',
      'Milk Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: android);
    await _notifications.show(
      0,
      "Milk Bill Alert 🥛",
      "Your milk cost is ₹${total.toStringAsFixed(0)} this month.",
      details,
    );
  }
}

// DASHBOARD
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  double groceryTotal = 0;
  double milkTotal = 0;
  double milkPerDay = 0;
  String userName = "";
  bool notificationDone = false;

  String? startDate;
  String? billDate;

  final String baseUrl = "https://home-expense-backend.onrender.com";

  @override
  void initState() {
    super.initState();
    initApp();
  }

  Future<void> initApp() async {
    final prefs = await SharedPreferences.getInstance();

    userName = prefs.getString("name") ?? "";
    milkPerDay = prefs.getDouble("milkPerDay") ?? 0;
    milkTotal = prefs.getDouble("milkTotalMonthly") ?? 0;
    startDate = prefs.getString("milkStartDate");
    billDate = prefs.getString("milkBillDate");
    notificationDone = prefs.getBool("milkAlertSent") ?? false;

    if (userName.isEmpty) askName();
    else if (milkPerDay == 0) askMilkPrice();
    else calculateMilk();

    fetchTotals();
  }

  void askName() {
    TextEditingController name = TextEditingController(text: userName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _prettyDialog(
          title: "Enter Name",
          child: TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: "Your name",
              prefixIcon: Icon(Icons.person),
            ),
          ),
          onSave: () async {
            if (name.text.isEmpty) return;

            final prefs = await SharedPreferences.getInstance();
            prefs.setString("name", name.text);

            userName = name.text;
            setState(() {});
            Navigator.pop(context);

            if (milkPerDay == 0) askMilkPrice();
          },
        );
      },
    );
  }

  void askMilkPrice() {
    TextEditingController price = TextEditingController(text: milkPerDay.toString());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _prettyDialog(
          title: "Enter Milk Price",
          child: TextField(
            controller: price,
            decoration: const InputDecoration(
              labelText: "Price per day",
              prefixIcon: Icon(Icons.local_drink),
            ),
            keyboardType: TextInputType.number,
          ),
          onSave: () async {
            milkPerDay = double.tryParse(price.text) ?? 0;

            final prefs = await SharedPreferences.getInstance();
            prefs.setDouble("milkPerDay", milkPerDay);

            DateTime now = DateTime.now();
            startDate = "${now.day}-${now.month}-${now.year}";
            DateTime bill = now.add(const Duration(days: 30));
            billDate = "${bill.day}-${bill.month}-${bill.year}";

            prefs.setString("milkStartDate", startDate!);
            prefs.setString("milkBillDate", billDate!);

            calculateMilk();
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void calculateMilk() async {
    final prefs = await SharedPreferences.getInstance();
    DateTime today = DateTime.now();
    String todayStr = "${today.year}-${today.month}-${today.day}";
    String? lastDate = prefs.getString("lastMilkUpdate");

    if (lastDate != todayStr) {
      milkTotal += milkPerDay;
      prefs.setDouble("milkTotalMonthly", milkTotal);
      prefs.setString("lastMilkUpdate", todayStr);
    }

    int lastDay = DateTime(today.year, today.month + 1, 0).day;

    if (today.day == lastDay && !notificationDone) {
      NotifyService.showMilkAlert(milkTotal);
      prefs.setBool("milkAlertSent", true);
      notificationDone = true;
    }

    setState(() {});
  }

  Future<void> fetchTotals() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/totals'));
      final data = jsonDecode(res.body);

      setState(() {
        groceryTotal = data["grocery"] ?? 0;
      });
    } catch (_) {}
  }

  void addGrocery() {
    TextEditingController item = TextEditingController();
    TextEditingController amount = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return _prettyDialog(
          title: "Add Grocery",
          child: Column(
            children: [
              TextField(
                controller: item,
                decoration: const InputDecoration(
                  labelText: "Item name",
                  prefixIcon: Icon(Icons.edit),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                decoration: const InputDecoration(
                  labelText: "Price",
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.number,
              )
            ],
          ),
          onSave: () async {
            await http.post(
              Uri.parse("$baseUrl/add_grocery"),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "item": item.text,
                "amount": amount.text,
                "category": "Grocery"
              }),
            );

            Navigator.pop(context);
            fetchTotals();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double monthlyProjected = milkPerDay * 30;

    return Scaffold(
      appBar: AppBar(
        title: Text("Hi, $userName 👋"),
        actions: [
          IconButton(icon: const Icon(Icons.person), onPressed: askName),
          IconButton(icon: const Icon(Icons.local_drink), onPressed: askMilkPrice),
          TextButton(
            onPressed: () async {
              final changed = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllExpensesScreen(baseUrl: baseUrl),
                ),
              );

              if (changed == true) {
                fetchTotals();
              }
            },
            child: const Text("All Expenses"),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addGrocery,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _totalCard(),
            const SizedBox(height: 18),
            Expanded(
              child: ListView(
                children: [
                  _featureCard(
                    title: "Milk",
                    amount: milkTotal,
                    running: "Running: ₹${milkTotal.toStringAsFixed(0)}",
                    monthly: "Monthly: ₹${monthlyProjected.toStringAsFixed(0)}",
                    startDate: startDate ?? "-",
                    billDate: billDate ?? "-",
                    icon: Icons.local_drink,
                    colors: [Colors.lightBlue.shade300, Colors.blue.shade600],
                    onTap: askMilkPrice,
                  ),
                  const SizedBox(height: 14),
                  _featureCard(
                    title: "Grocery",
                    amount: groceryTotal,
                    icon: Icons.shopping_cart,
                    colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                    onTap: addGrocery,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _totalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Total Expense", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            "₹ ${(milkTotal + groceryTotal).toStringAsFixed(0)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCard({
    required String title,
    required double amount,
    required IconData icon,
    required List<Color> colors,
    VoidCallback? onTap,
    String? running,
    String? monthly,
    String? startDate,
    String? billDate,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 175,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (running != null)
                    Text(running, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  if (monthly != null)
                    Text(monthly, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  Text(
                    "₹ ${amount.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (startDate != null && billDate != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Started:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(startDate, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text("Bill on:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(billDate, style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              )
          ],
        ),
      ),
    );
  }
}

Widget _prettyDialog({
  required String title,
  required Widget child,
  required VoidCallback onSave,
}) {
  return AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    content: child,
    actions: [
      ElevatedButton(onPressed: onSave, child: const Text("Save"))
    ],
  );
}

// ALL EXPENSES SCREEN
class AllExpensesScreen extends StatefulWidget {
  final String baseUrl;
  const AllExpensesScreen({super.key, required this.baseUrl});

  @override
  State<AllExpensesScreen> createState() => _AllExpensesScreenState();
}

class _AllExpensesScreenState extends State<AllExpensesScreen> {
  List expenses = [];
  bool changed = false;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final res = await http.get(Uri.parse("${widget.baseUrl}/all"));
    setState(() => expenses = jsonDecode(res.body));
  }

  Future<void> deleteItem(int id) async {
    await http.delete(Uri.parse("${widget.baseUrl}/delete/$id"));

    await fetchData();
    changed = true;
    setState(() {});

    // AUTO CLOSE WHEN LAST ITEM DELETED
    if (expenses.isEmpty) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("All Expenses")),
        body: ListView.builder(
          itemCount: expenses.length,
          itemBuilder: (_, i) {
            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                leading: Icon(
                  expenses[i]["category"] == "Grocery"
                      ? Icons.shopping_cart
                      : Icons.local_drink,
                ),
                title: Text(expenses[i]["item"]),
                subtitle: Text("₹${expenses[i]["amount"]}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => deleteItem(expenses[i]["id"]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
