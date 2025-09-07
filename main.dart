import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';
import 'package:fl_chart/fl_chart.dart';
import 'presets_page.dart';
import 'reporting.dart';

void main() {
  Intl.defaultLocale = 'pt_BR';
  runApp(const AppEspetos());
}

class AppEspetos extends StatelessWidget {
  const AppEspetos({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Espetos • Vendas',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;
  final pages = const [RegistrarVendaPage(), HistoricoDiaPage(), DashboardPage()];

  void _openPresets() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PresetsPage())).then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espetos • Vendas'),
        actions: [
          IconButton(onPressed: _openPresets, icon: const Icon(Icons.restaurant_menu)),
        ],
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.flash_on), label: 'Rápido'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Hoje'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Dashboard'),
        ],
      ),
    );
  }
}

class RegistrarVendaPage extends StatefulWidget {
  const RegistrarVendaPage({super.key});
  @override
  State<RegistrarVendaPage> createState() => _RegistrarVendaPageState();
}

class _RegistrarVendaPageState extends State<RegistrarVendaPage> {
  late Future<List<Preset>> _presetsFut;
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _presetsFut = DBHelper().getAllPresets();
    setState(() {});
  }

  Future<void> _quickAdd(Preset p) async {
    _qtyCtrl.text = '1';
    _priceCtrl.text = p.defaultPrice.toStringAsFixed(2);
    _costCtrl.text = p.unitCost.toStringAsFixed(2);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Categoria: ${p.category}'),
            const SizedBox(height: 8),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Preço unitário'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Custo unitário'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Registrar')),
        ],
      ),
    );

    if (ok == true) {
      final qty = int.tryParse(_qtyCtrl.text) ?? 1;
      final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? p.defaultPrice;
      final cost = double.tryParse(_costCtrl.text.replaceAll(',', '.')) ?? p.unitCost;
      final sale = Sale(
        dateMillis: DateTime.now().millisecondsSinceEpoch,
        item: p.name,
        qty: qty,
        unitPrice: price,
        unitCost: cost,
      );
      await DBHelper().insertSale(sale);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registrado: ${p.name} x$qty')),
        );
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Preset>>(
      future: _presetsFut,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final presets = snap.data!;
        if (presets.isEmpty) {
          return Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PresetsPage()))
                  .then((_) => _reload()),
              icon: const Icon(Icons.add),
              label: const Text('Adicione seus sabores'),
            ),
          );
        }

        final byCat = <String, List<Preset>>{};
        for (final p in presets) {
          byCat.putIfAbsent(p.category, () => []).add(p);
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: byCat.entries.map((e) {
            final cat = e.key;
            final items = e.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(cat, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.6,
                  ),
                  itemBuilder: (_, i) {
                    final p = items[i];
                    return ElevatedButton(
                      onPressed: () => _quickAdd(p),
                      child: Text(
                        p.name,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

class HistoricoDiaPage extends StatefulWidget {
  const HistoricoDiaPage({super.key});
  @override
  State<HistoricoDiaPage> createState() => _HistoricoDiaPageState();
}

class _HistoricoDiaPageState extends State<HistoricoDiaPage> {
  late Future<List<Sale>> _future;
  late Future<double> _totalFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final today = DateTime.now();
    _future = DBHelper().getSalesByDay(today);
    _totalFuture = DBHelper().getDailyTotal(today);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder(
        future: Future.wait([_future, _totalFuture]),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sales = snap.data![0] as List<Sale>;
          final total = snap.data![1] as double;
          final avgTicket = sales.isEmpty ? 0.0 : total / sales.length;
          final profit = sales.fold<double>(0.0, (p, s) => p + s.profit);

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: sales.length + 1,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  children: [
                    ListTile(
                      title: const Text('Total do dia'),
                      trailing: Text(currency.format(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ListTile(
                      title: const Text('Lucro do dia'),
                      trailing: Text(currency.format(profit)),
                    ),
                    ListTile(
                      title: const Text('Ticket médio (por venda)'),
                      trailing: Text(currency.format(avgTicket)),
                    ),
                  ],
                );
              }
              final s = sales[i - 1];
              final dt = DateTime.fromMillisecondsSinceEpoch(s.dateMillis);
              return ListTile(
                title: Text('${s.item}  x${s.qty}'),
                subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(dt)),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(currency.format(s.total)),
                    Text('Lucro: ${currency.format(s.profit)}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, double>> _monthly;
  DateTimeRange? _range;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _monthly = DBHelper().getMonthlyTotals(monthsBack: 6);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial = _range ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
      saveText: 'Aplicar',
      helpText: 'Filtrar por período',
      cancelText: 'Cancelar',
    );
    if (r != null) setState(() => _range = r);
  }

  Future<void> _makePdf() async {
    final file = await Reports.buildMonthlyPdf(_year, _month);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF gerado: ${file.path}')));
    await Reports.shareFile(file);
  }

  Future<void> _exportCsv() async {
    final r = _range ?? DateTimeRange(
      start: DateTime(_year, _month, 1),
      end: DateTime(_year, _month + 1, 0),
    );
    final file = await Reports.exportCsv(r.start, r.end);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV gerado: ${file.path}')));
    await Reports.shareFile(file);
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    return FutureBuilder<Map<String, double>>(
      future: _monthly,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!;
        final months = data.keys.toList()..sort();
        final values = months.map((m) => data[m] ?? 0.0).toList();

        final bars = <BarChartGroupData>[];
        for (int i = 0; i < months.length; i++) {
          bars.add(
            BarChartGroupData(
              x: i,
              barRods: [BarChartRodData(toY: values[i])],
              showingTooltipIndicators: [0],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _month,
                      decoration: const InputDecoration(labelText: 'Mês'),
                      items: List.generate(12, (i) => i + 1)
                          .map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))))
                          .toList(),
                      onChanged: (v) => setState(() => _month = v ?? _month),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _year,
                      decoration: const InputDecoration(labelText: 'Ano'),
                      items: List.generate(6, (i) => DateTime.now().year - i)
                          .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                          .toList(),
                      onChanged: (v) => setState(() => _year = v ?? _year),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.filter_alt),
                      label: Text(_range == null
                          ? 'Filtrar período (opcional)'
                          : 'Período: ${DateFormat('dd/MM').format(_range!.start)} - ${DateFormat('dd/MM').format(_range!.end)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _makePdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('PDF do mês'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _exportCsv,
                      icon: const Icon(Icons.table_view),
                      label: const Text('Exportar CSV'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Faturamento mensal (últimos 6 meses)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: BarChart(
                  BarChartData(
                    barGroups: bars,
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= months.length) return const SizedBox.shrink();
                            final ym = months[i].split('-');
                            final mm = int.parse(ym[1]);
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${mm.toString().padLeft(2, '0')}'),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 56,
                          getTitlesWidget: (value, meta) => Text(currency.format(value)),
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final ym = months[group.x.toInt()];
                          return BarTooltipItem(
                            '${ym.substring(5)}/${ym.substring(0,4)}\n${currency.format(rod.toY)}',
                            const TextStyle(fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: DBHelper().getMonthlySummary(_year, _month),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final s = snap.data!;
                  return Column(
                    children: [
                      const Divider(),
                      ListTile(
                        title: const Text('Faturamento do mês'),
                        trailing: Text(currency.format(s['totalRevenue'])),
                      ),
                      ListTile(
                        title: const Text('Lucro do mês'),
                        trailing: Text(currency.format(s['totalProfit'])),
                      ),
                      ListTile(
                        title: const Text('Ticket médio (por venda)'),
                        trailing: Text(currency.format(s['avgTicket'])),
                      ),
                      ListTile(
                        title: const Text('Margem média'),
                        trailing: Text('${(s['marginPct'] as double).toStringAsFixed(1)}%'),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
