import 'package:flutter_riverpod/flutter_riverpod.dart';

final startupIntroProvider = NotifierProvider<StartupIntro, bool>(
  StartupIntro.new,
);

class StartupIntro extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() => state = true;
}
