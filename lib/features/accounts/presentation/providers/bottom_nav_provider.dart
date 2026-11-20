import 'package:flutter_riverpod/legacy.dart';

import '../../../auth/presentation/providers/auth_provider.dart';

final bottomNavIndexProvider = StateProvider<int>((ref) {
  ref.watch(activeSessionProvider);
  return 0;
});
