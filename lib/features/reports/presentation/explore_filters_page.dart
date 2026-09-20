import 'package:flutter/material.dart';

import '../../submissions/domain/submission.dart';
import '../domain/explore_filter.dart';
import '../domain/report.dart';

class ExploreFiltersPage extends StatefulWidget {
  const ExploreFiltersPage({required this.initial, super.key});
  final ExploreFilter initial;
  @override
  State<ExploreFiltersPage> createState() => _ExploreFiltersPageState();
}

class _ExploreFiltersPageState extends State<ExploreFiltersPage> {
  late Set<String> categories = {...widget.initial.categories};
  late Set<TrackingStatus> statuses = {...widget.initial.statuses};
  late DateTime? from = widget.initial.from, until = widget.initial.until;
  Future<void> pick(bool start) async {
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 4));
    final date = await showDatePicker(
      context: context,
      initialDate:
          (start ? from : until) ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (date != null && mounted) {
      setState(() {
        if (start) {
          from = date;
        } else {
          until = date;
        }
      });
    }
  }

  String dateLabel(DateTime? date) =>
      date == null ? 'Sin límite' : '${date.day}/${date.month}/${date.year}';
  @override
  Widget build(BuildContext context) {
    final invalid = from != null && until != null && from!.isAfter(until!);
    return Scaffold(
      appBar: AppBar(title: const Text('Filtros')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Categorías', style: Theme.of(context).textTheme.titleLarge),
              const Text('Sin selección se incluyen todas las categorías.'),
              for (final category in reportCategories)
                CheckboxListTile(
                  title: Text(category),
                  value: categories.contains(category),
                  onChanged: (value) => setState(() {
                    value!
                        ? categories.add(category)
                        : categories.remove(category);
                  }),
                ),
              Text(
                'Seguimiento',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final status in TrackingStatus.values)
                CheckboxListTile(
                  title: Text(status.label),
                  value: statuses.contains(status),
                  onChanged: (value) => setState(() {
                    value! ? statuses.add(status) : statuses.remove(status);
                  }),
                ),
              const Text('Última observación · fecha de Bolivia (inclusive)'),
              OutlinedButton(
                onPressed: () => pick(true),
                child: Text('Desde: ${dateLabel(from)}'),
              ),
              OutlinedButton(
                onPressed: () => pick(false),
                child: Text('Hasta: ${dateLabel(until)}'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  from = null;
                  until = null;
                }),
                child: const Text('Quitar fechas'),
              ),
              if (invalid)
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'La fecha inicial debe ser anterior o igual a la final.',
                  ),
                ),
              OutlinedButton(
                onPressed: () => setState(() {
                  categories.clear();
                  statuses = {...const ExploreFilter().statuses};
                  from = null;
                  until = null;
                }),
                child: const Text('Restablecer filtros abiertos'),
              ),
              FilledButton(
                onPressed: invalid
                    ? null
                    : () => Navigator.pop(
                        context,
                        ExploreFilter(
                          categories: categories,
                          statuses: statuses,
                          from: from,
                          until: until,
                        ),
                      ),
                child: const Text('Aplicar filtros'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
