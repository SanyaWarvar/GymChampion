import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../data/template_repository.dart';
import '../domain/workout_template.dart';

class TemplateListScreen extends StatelessWidget {
  const TemplateListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = TemplateRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Шаблоны')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/workout/templates/edit'),
        icon: const Icon(Icons.add),
        label: const Text('Новый'),
      ),
      body: StreamBuilder<List<WorkoutTemplate>>(
        stream: repo.watchTemplates(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Не удалось загрузить шаблоны',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final templates = snapshot.data!;
          if (templates.isEmpty) {
            return const Center(
              child: Text(
                'Пока нет шаблонов.\nСоздай свой под любимую тренировку.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          final sections = _templateSections(templates);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final item = sections[index];
              if (item is _SectionTitle) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(4, index == 0 ? 0 : 16, 4, 8),
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                );
              }
              final t = (item as _SectionTemplate).template;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TemplateTile(template: t, repo: repo),
              );
            },
          );
        },
      ),
    );
  }
}

const _programOrder = ['stronglifts', 'starting_strength', 'run'];

List<Object> _templateSections(List<WorkoutTemplate> templates) {
  final byProgram = <String, List<WorkoutTemplate>>{};
  final others = <WorkoutTemplate>[];
  for (final t in templates) {
    if (t.isProgramDay) {
      byProgram.putIfAbsent(t.programId!, () => []).add(t);
    } else {
      others.add(t);
    }
  }

  final items = <Object>[];
  final programIds = [
    ..._programOrder.where(byProgram.containsKey),
    ...byProgram.keys.where((id) => !_programOrder.contains(id)),
  ];
  for (final id in programIds) {
    final days = [...byProgram[id]!]
      ..sort((a, b) => (a.dayLabel ?? a.name).compareTo(b.dayLabel ?? b.name));
    items.add(_SectionTitle(days.first.programTitle ?? id));
    items.addAll(days.map(_SectionTemplate.new));
  }
  if (others.isNotEmpty) {
    items.add(const _SectionTitle('Другие'));
    items.addAll(others.map(_SectionTemplate.new));
  }
  return items;
}

class _SectionTitle {
  const _SectionTitle(this.title);
  final String title;
}

class _SectionTemplate {
  const _SectionTemplate(this.template);
  final WorkoutTemplate template;
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.repo});

  final WorkoutTemplate template;
  final TemplateRepository repo;

  @override
  Widget build(BuildContext context) {
    final t = template;
    final first = t.exercises.isNotEmpty ? t.exercises.first : null;
    final subtitle = t.exercises.isEmpty
        ? 'Нет упражнений'
        : t.exercises.map((e) => e.name).join(' · ');
    return ListTile(
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      leading: first == null
          ? const Icon(Icons.playlist_play, color: AppColors.amber)
          : ExerciseIcon(
              exerciseId: first.exerciseId,
              name: first.name,
              size: 40,
              radius: 10,
            ),
      title: Text(
        t.dayLabel ?? t.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.muted),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'start') {
            context.push('/workout/active', extra: t);
          } else if (value == 'edit') {
            context.push('/workout/templates/edit', extra: t);
          } else if (value == 'delete') {
            await repo.deleteTemplate(t.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'start', child: Text('Старт')),
          PopupMenuItem(value: 'edit', child: Text('Изменить')),
          PopupMenuItem(value: 'delete', child: Text('Удалить')),
        ],
      ),
      onTap: () => context.push('/workout/active', extra: t),
    );
  }
}
