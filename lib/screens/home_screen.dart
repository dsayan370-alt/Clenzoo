import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/call_service.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late WebViewController _wc;
  bool _loading = true;
  Map<String, dynamic> _stats = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _loadStats();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadStats());
  }

  void _initWebView() {
    _wc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('CZ', onMessageReceived: _onMsg)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) {
          setState(() => _loading = false);
          _inject();
        },
        onNavigationRequest: (req) {
          if (req.url.startsWith('tel:')) {
            CallService.instance.dial(req.url.replaceFirst('tel:', ''));
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse('https://clenzoo.com/login/pending_calls.php'));
  }

  Future<void> _inject() async {
    // Save token if PHP injected it
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('agent_token') ?? '';

    await _wc.runJavaScript('''
(function(){
  // Intercept all Call buttons
  function patchCalls(){
    document.querySelectorAll('a[href^="tel:"],.pc-btn-call').forEach(function(el){
      var num = (el.href||'').replace('tel:','') || el.dataset.num || '';
      if(!num) return;
      el.onclick = function(e){ e.preventDefault(); CZ.postMessage(JSON.stringify({a:'call',n:num})); };
    });
  }
  patchCalls();
  new MutationObserver(patchCalls).observe(document.body,{childList:true,subtree:true});

  // Pick up token that PHP injected
  if(window.__czToken){
    CZ.postMessage(JSON.stringify({a:'token',t:window.__czToken}));
  }

  // Send saved token back to page context
  window.__czAppToken = '${savedToken}';
})();
''');
  }

  void _onMsg(JavaScriptMessage msg) async {
    try {
      final d = jsonDecode(msg.message) as Map<String, dynamic>;
      switch (d['a']) {
        case 'call':
          await CallService.instance.dial(d['n'] as String);
          break;
        case 'token':
          final t = d['t'] as String? ?? '';
          if (t.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('agent_token', t);
          }
          break;
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    final s = await CallService.getStats();
    if (mounted) setState(() => _stats = s);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Custom AppBar
          Container(
            color: const Color(0xFF0a6cff),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 6,
              bottom: 8, left: 16, right: 8,
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_in_talk, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Clenzoo Agent',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 17)),
                ),
                // Stats chips
                _chip(Icons.check_circle_outline,
                    '${_stats['valid_calls'] ?? 0}', Colors.greenAccent),
                const SizedBox(width: 6),
                _chip(Icons.currency_rupee,
                    (_stats['total_commission'] ?? 0.0).toStringAsFixed(0),
                    Colors.amber),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.bar_chart, color: Colors.white),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const StatsScreen())),
                ),
              ],
            ),
          ),
          // Stats bar
          _statsBar(),
          // WebView
          Expanded(
            child: Stack(children: [
              WebViewWidget(controller: _wc),
              if (_loading) const Center(
                child: CircularProgressIndicator(color: Color(0xFF0a6cff)),
              ),
            ]),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: const Color(0xFF0a6cff),
        onPressed: () { _wc.reload(); _loadStats(); },
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _chip(IconData icon, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white15,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(val, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  Widget _statsBar() {
    final total   = _stats['total_calls']       ?? 0;
    final valid   = _stats['valid_calls']        ?? 0;
    final missed  = _stats['missed_calls']       ?? 0;
    final comm    = (_stats['total_commission']  ?? 0.0) as num;
    final secs    = (_stats['total_seconds']     ?? 0)   as num;

    return Container(
      color: const Color(0xFF0850cc),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        _bar('Total',  '$total',              Icons.call,          Colors.white60),
        _bar('Valid',  '$valid',              Icons.check_circle,  Colors.greenAccent),
        _bar('Missed', '$missed',             Icons.call_missed,   Colors.redAccent),
        _bar('Earned', '₹${comm.toInt()}',   Icons.currency_rupee,Colors.amber),
        _bar('Talk',   '${secs ~/ 60}m',     Icons.timer,         Colors.cyanAccent),
      ]),
    );
  }

  Widget _bar(String label, String val, IconData icon, Color color) {
    return Expanded(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 2),
          Text(val, style: TextStyle(color: color,
              fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    ));
  }
}
