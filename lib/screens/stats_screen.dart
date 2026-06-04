import 'package:flutter/material.dart';
import '../services/call_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic> _stats    = {};
  Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      CallService.getStats(),
      CallService.getSettings(),
      CallService.getHistory(),
    ]);
    if (mounted) setState(() {
      _stats    = results[0] as Map<String, dynamic>;
      _settings = results[1] as Map<String, dynamic>;
      _logs     = results[2] as List<Map<String, dynamic>>;
      _loading  = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a6cff),
        foregroundColor: Colors.white,
        title: const Text('Stats & Earnings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0a6cff)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(14), children: [
                _rulesCard(),
                const SizedBox(height: 14),
                _statsGrid(),
                const SizedBox(height: 14),
                _historySection(),
              ]),
            ),
    );
  }

  // ── Rules card ─────────────────────────────────────────
  Widget _rulesCard() {
    final minSec  = _settings['min_duration_seconds']  ?? 30;
    final commVal = _settings['commission_per_call']   ?? 0;
    final commMis = _settings['commission_missed']     ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0a6cff), Color(0xFF1d4ed8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('YOUR CALL RULES', style: TextStyle(
            color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600,
            letterSpacing: 0.8)),
        const SizedBox(height: 12),
        Row(children: [
          _ruleBox('⏱', '${minSec}s', 'Min Duration'),
          const SizedBox(width: 8),
          _ruleBox('✅', '₹$commVal', 'Valid Call'),
          const SizedBox(width: 8),
          _ruleBox('📵', commMis == 0 ? '—' : '₹$commMis', 'Missed Call'),
        ]),
      ]),
    );
  }

  Widget _ruleBox(String emoji, String val, String label) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white15,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10),
            textAlign: TextAlign.center),
      ]),
    ));
  }

  // ── Stats grid ─────────────────────────────────────────
  Widget _statsGrid() {
    final total  = _stats['total_calls']       ?? 0;
    final valid  = _stats['valid_calls']        ?? 0;
    final missed = _stats['missed_calls']       ?? 0;
    final comm   = (_stats['total_commission']  ?? 0.0) as num;
    final secs   = (_stats['total_seconds']     ?? 0)   as num;
    final rate   = total > 0 ? '${((valid / total) * 100).toInt()}%' : '—';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("TODAY'S PERFORMANCE", style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748b),
          letterSpacing: 0.8)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.7,
        children: [
          _sc('Total Calls',   '$total',            Icons.call,          const Color(0xFF0a6cff), const Color(0xFFEFF6FF)),
          _sc('Valid Calls',   '$valid',             Icons.check_circle,  const Color(0xFF15803d), const Color(0xFFEAF3DE)),
          _sc('Missed',        '$missed',            Icons.call_missed,   const Color(0xFFdc2626), const Color(0xFFFCEBEB)),
          _sc('Earned Today',  '₹${comm.toInt()}',  Icons.currency_rupee,const Color(0xFFa16207), const Color(0xFFFAEEDA)),
          _sc('Talk Time',     '${secs ~/ 60}m',    Icons.timer,         const Color(0xFF0e7490), const Color(0xFFE1F5EE)),
          _sc('Success Rate',  rate,                Icons.trending_up,   const Color(0xFF7c3aed), const Color(0xFFEEEDFE)),
        ],
      ),
    ]);
  }

  Widget _sc(String label, String val, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(icon, color: color, size: 18),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: TextStyle(color: color,
              fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 10)),
        ]),
      ]),
    );
  }

  // ── History ────────────────────────────────────────────
  Widget _historySection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('RECENT CALLS', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748b),
          letterSpacing: 0.8)),
      const SizedBox(height: 8),
      if (_logs.isEmpty)
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Column(children: [
            Icon(Icons.phone_disabled, size: 40, color: Color(0xFFCBD5E1)),
            SizedBox(height: 8),
            Text('Abhi koi call nahi', style: TextStyle(color: Color(0xFF94A3B8))),
          ])),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _logCard(_logs[i]),
        ),
    ]);
  }

  Widget _logCard(Map<String, dynamic> log) {
    final valid   = (log['is_valid'] as int? ?? 0) == 1;
    final contact = log['contact'] as String? ?? '—';
    final dur     = log['duration_seconds'] as int? ?? 0;
    final type    = log['call_type'] as String? ?? 'outgoing';
    final comm    = (log['commission_paid'] as num?)?.toDouble() ?? 0;
    final ts      = log['created_at'] as String? ?? '';

    String time = '';
    try {
      final dt = DateTime.parse(ts).toLocal();
      time = '${dt.day}/${dt.month}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    final isMissed = type == 'missed';
    final iconColor = isMissed
        ? const Color(0xFFdc2626)
        : valid ? const Color(0xFF15803d) : const Color(0xFF64748b);
    final iconBg = isMissed
        ? const Color(0xFFFCEBEB)
        : valid ? const Color(0xFFEAF3DE) : const Color(0xFFF1F5F9);
    final icon = isMissed
        ? Icons.call_missed
        : valid ? Icons.call : Icons.call_end;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: valid ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: iconBg,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(contact, style: const TextStyle(fontWeight: FontWeight.w600,
              fontSize: 13, color: Color(0xFF1E293B))),
          Text('${dur}s  ·  $time',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ])),
        if (valid && comm > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFFEAF3DE),
                borderRadius: BorderRadius.circular(20)),
            child: Text('+₹${comm.toInt()}',
                style: const TextStyle(color: Color(0xFF15803d),
                    fontWeight: FontWeight.bold, fontSize: 12)),
          )
        else if (!valid && !isMissed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('Too short',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
          ),
      ]),
    );
  }
}
