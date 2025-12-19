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

// ------------------------------------------------------
// 🔔 NOTIFICATION SERVICE
// ------------------------------------------------------
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
      "Your milk cost reached ₹${total.toStringAsFixed(0)} this month.",
      details,
    );
  }
}

// ------------------------------------------------------
// DASHBOARD
// ------------------------------------------------------

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
    notificationDone = prefs.getBool("milkAlertSent") ?? false;

    if (userName.isEmpty) askName();
    else if (milkPerDay == 0) askMilkPrice();
    else calculateMilk();

    fetchTotals();
  }

  // ASK USER NAME
  void askName() {
    TextEditingController name = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _prettyDialog(
          title: "Welcome!",
          child: TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: "Enter your name",
              prefixIcon: Icon(Icons.person),
            ),
          ),
          onSave: () async {
            if (name.text.isEmpty) return;
            final prefs = await SharedPreferences.getInstance();
            prefs.setString("name", name.text);
            Navigator.pop(context);
            askMilkPrice();
          },
        );
      },
    );
  }

  // ASK MILK PRICE
  void askMilkPrice() {
    TextEditingController price = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _prettyDialog(
          title: "Milk Setup",
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

            calculateMilk();
            Navigator.pop(context);
          },
        );
      },
    );
  }

  // ------------------------------------------------------
  // 🆕 MILK CALCULATION + MONTH END NOTIFICATION
  // ------------------------------------------------------
  void calculateMilk() async {
    milkTotal = milkPerDay * 30;

    DateTime now = DateTime.now();
    int lastDay = DateTime(now.year, now.month + 1, 0).day;

    /// notify only on last day of month
    if (now.day == lastDay && !notificationDone) {
      NotifyService.showMilkAlert(milkTotal);
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool("milkAlertSent", true);
      notificationDone = true;
    }

    setState(() {});
  }

  // FETCH TOTALS
  Future<void> fetchTotals() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/totals'));
      final data = jsonDecode(res.body);

      setState(() {
        groceryTotal = data["grocery"] ?? 0;
      });
    } catch (e) {}
  }

  // ADD GROCERY
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

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hi, $userName 👋"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AllExpensesScreen(baseUrl: baseUrl),
                ),
              );
            },
            child: const Text("All Expenses"),
          )
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
                    subtitle: "₹${milkPerDay.toStringAsFixed(0)} / day",
                    icon: Icons.local_drink,
                    colors: [Colors.lightBlue.shade300, Colors.blue.shade600],
                  ),
                  const SizedBox(height: 14),
                  _featureCard(
                    title: "Grocery",
                    amount: groceryTotal,
                    icon: Icons.shopping_cart,
                    colors: [Colors.orange.shade400, Colors.deepOrange.shade400],
                    onTap: addGrocery,
                  )
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
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 135,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 17)),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                Text(
                  "₹ ${amount.toStringAsFixed(0)}",
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// Dialog function
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
      ElevatedButton(
        onPressed: onSave,
        child: const Text("Save"),
      )
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

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    final res = await http.get(Uri.parse("${widget.baseUrl}/all"));
    setState(() {
      expenses = jsonDecode(res.body);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              trailing: Text("₹${expenses[i]["amount"]}"),
            ),
          );
        },
      ),
    );
  }
}
