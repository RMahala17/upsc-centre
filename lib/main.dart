import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/platform/platform_services.dart';
import 'core/storage/db.dart';
import 'features/syllabus/data/syllabus_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Db.instance.init();
  await seedGsSubjectsIfNeeded();
  // Browsers may clear a site's storage when space runs low. Asking for
  // "persistent" storage makes that much less likely. Does nothing on
  // platforms without the feature.
  unawaited(requestPersistentStorage());
  runApp(const ProviderScope(child: UpscApp()));
}
