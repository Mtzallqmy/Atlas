import 'package:anatomy_atlas/features/organs/data/organ_repository.dart';
import 'package:anatomy_atlas/features/organs/domain/organ.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final organsProvider = FutureProvider<List<Organ>>((ref) => ref.watch(organRepositoryProvider).list());
final organBySlugProvider = FutureProvider.family<Organ?, String>((ref, slug) => ref.watch(organRepositoryProvider).bySlug(slug));
