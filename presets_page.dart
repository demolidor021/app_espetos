import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

class PresetsPage extends StatefulWidget {
  const PresetsPage({super.key});

  @override
  State<PresetsPage> createState() => _PresetsPageState();
}

class _PresetsPageState extends State<PresetsPage> {
  late Future<List<Preset>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = DBHelper().getAllPresets();
    setState(() {});
  }

  void _edit([Preset? p]) async {
    final res = await showDialog<Preset>(
      context: context,
      builder: (_) => _PresetDialog(preset: p),
    );
    if (res != null) {
      await DBHelper().upsertPreset(res);
      if (mounted) _reload();
    }
  }

  Future<void> _delete(Preset p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover sabor?'),
        content: Text('Tem certeza que deseja remover "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok == true) {
      await DBHelper().deletePreset(p.id!);
      if (mounted) _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.simpleCurrency(locale: 'pt_BR');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sabores'),
        actions: [
          IconButton(onPressed: () => _edit(), icon: const Icon(Icons.add)),
        ],
      ),
      body: FutureBuilder<List<Preset>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('Nenhum sabor cadastrado. Toque em + para adicionar.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = items[i];
              return ListTile(
                title: Text(p.name),
                subtitle: Text('${p.category} • ${currency.format(p.defaultPrice)} • Custo: ${currency.format(p.unitCost)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(onPressed: () => _edit(p), icon: const Icon(Icons.edit)),
                    IconButton(onPressed: () => _delete(p), icon: const Icon(Icons.delete_outline)),
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

class _PresetDialog extends StatefulWidget {
  final Preset? preset;
  const _PresetDialog({required this.preset});

  @override
  State<_PresetDialog> createState() => _PresetDialogState();
}

class _PresetDialogState extends State<_PresetDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _cat = TextEditingController();
  final _cost = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    if (p != null) {
      _name.text = p.name;
      _price.text = p.defaultPrice.toStringAsFixed(2);
      _cat.text = p.category;
      _cost.text = p.unitCost.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _cat.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.preset == null ? 'Novo sabor' : 'Editar sabor'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome (ex: Espeto de Frango)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Preço padrão'),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Preço inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Custo unitário'),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null || n < 0) return 'Custo inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cat,
                decoration: const InputDecoration(labelText: 'Categoria (ex: Carnes, Frango, Doces)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a categoria' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final price = double.parse(_price.text.replaceAll(',', '.'));
            final cost = double.parse(_cost.text.replaceAll(',', '.'));
            final p = Preset(
              id: widget.preset?.id,
              name: _name.text.trim(),
              defaultPrice: price,
              category: _cat.text.trim(),
              unitCost: cost,
            );
            Navigator.pop(context, p);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
