import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Override if the laptop changes networks: flutter run --dart-define=API_BASE_URL=http://192.168.1.6:3000
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://192.168.1.6:3000');
bool successful(http.Response response) => response.statusCode >= 200 && response.statusCode < 300;

void main() => runApp(const SnapOdrApp());

class SnapOdrApp extends StatelessWidget {
  const SnapOdrApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SnapOdr Staff',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFC72C)), useMaterial3: true),
    home: const LoginScreen(),
  );
}

class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'staff@awaracafe.test');
  final password = TextEditingController(text: 'AwaraDemo123!');
  bool loading = false; String? error;
  Future<void> login() async {
    setState(() { loading = true; error = null; });
    try {
      final response = await http.post(Uri.parse('$apiBaseUrl/api/staff/login'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email.text, 'password': password.text}));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!successful(response)) throw Exception(data['error'] ?? 'Login failed');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrdersScreen(token: data['token'] as String, restaurant: (data['restaurant'] as Map<String, dynamic>)['slug'] as String)));
    } catch (e) { setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => loading = false); }
  }
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('SnapOdr Staff', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Sign in to manage live orders'), const SizedBox(height: 28), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')), const SizedBox(height: 12), TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')), if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))), const SizedBox(height: 22), FilledButton(onPressed: loading ? null : login, child: Text(loading ? 'Signing in…' : 'Sign in'))]))))));
}

class OrdersScreen extends StatefulWidget { const OrdersScreen({super.key, required this.token, required this.restaurant}); final String token, restaurant; @override State<OrdersScreen> createState() => _OrdersScreenState(); }
class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> orders = []; String? error; Timer? poller;
  @override void initState() { super.initState(); load(); poller = Timer.periodic(const Duration(seconds: 4), (_) => load()); }
  @override void dispose() { poller?.cancel(); super.dispose(); }
  Future<void> load() async { try { final response = await http.get(Uri.parse('$apiBaseUrl/api/orders?restaurant=${widget.restaurant}'), headers: {'Authorization': 'Bearer ${widget.token}'}); final data = jsonDecode(response.body) as Map<String, dynamic>; if (!successful(response)) throw Exception(data['error'] ?? 'Could not load orders'); if (mounted) setState(() { orders = data['orders'] as List<dynamic>; error = null; }); } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Live Orders'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]), body: error != null ? Center(child: Text(error!)) : RefreshIndicator(onRefresh: load, child: ListView.builder(itemCount: orders.length, itemBuilder: (_, index) { final order = orders[index] as Map<String, dynamic>; final session = order['session'] as Map<String, dynamic>; final items = order['items'] as List<dynamic>; return Card(margin: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: ListTile(title: Text('Table ${(session['table'] as Map<String, dynamic>)['label']} · #${(order['id'] as String).substring((order['id'] as String).length - 6)}'), subtitle: Text('${items.length} item(s) · ${order['status']}'), trailing: const Icon(Icons.chevron_right), onTap: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetail(order: order, token: widget.token))); load(); })); })));
}

class OrderDetail extends StatefulWidget { const OrderDetail({super.key, required this.order, required this.token}); final Map<String, dynamic> order; final String token; @override State<OrderDetail> createState() => _OrderDetailState(); }
class _OrderDetailState extends State<OrderDetail> {
  late Map<String, dynamic> order; bool saving = false; String? error;
  @override void initState() { super.initState(); order = widget.order; }
  String? next(String status) { const steps = {'pending': 'accepted', 'accepted': 'preparing', 'preparing': 'ready', 'ready': 'served', 'served': 'completed'}; return steps[status]; }
  Future<void> advance() async { final status = next(order['status'] as String); if (status == null) return; setState(() { saving = true; error = null; }); try { final response = await http.patch(Uri.parse('$apiBaseUrl/api/orders/${order['id']}'), headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'}, body: jsonEncode({'status': status})); final data = jsonDecode(response.body) as Map<String, dynamic>; if (!successful(response)) throw Exception(data['error'] ?? 'Could not update order'); setState(() => order = data['order'] as Map<String, dynamic>); } catch (e) { setState(() => error = e.toString().replaceFirst('Exception: ', '')); } finally { if (mounted) setState(() => saving = false); } }
  @override Widget build(BuildContext context) { final items = order['items'] as List<dynamic>; final status = order['status'] as String; final following = next(status); return Scaffold(appBar: AppBar(title: const Text('Order detail')), body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text('Status: ${status.toUpperCase()}', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16), ...items.map((raw) { final item = raw as Map<String, dynamic>; return ListTile(title: Text((item['menuItem'] as Map<String, dynamic>)['name'] as String), trailing: Text('×${item['quantity']}')); }), const Spacer(), if (error != null) Text(error!, style: const TextStyle(color: Colors.red)), if (following != null) FilledButton(onPressed: saving ? null : advance, child: Text(saving ? 'Updating…' : 'Mark as $following')) else const Text('This order is complete.', textAlign: TextAlign.center)]))); }
}
