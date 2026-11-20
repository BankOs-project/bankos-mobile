import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/startup_intro_provider.dart';

class SessionStartupScreen extends ConsumerStatefulWidget {
  const SessionStartupScreen({super.key});

  @override
  ConsumerState<SessionStartupScreen> createState() =>
      _SessionStartupScreenState();
}

class _SessionStartupScreenState extends ConsumerState<SessionStartupScreen>
    with SingleTickerProviderStateMixin {
  late final _intro =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          ref.read(startupIntroProvider.notifier).complete();
        }
      });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (ref.read(startupIntroProvider)) return;
    if (reduceMotion) {
      _intro.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(startupIntroProvider.notifier).complete();
      });
    } else if (!_intro.isAnimating) {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startup = ref.watch(authProvider.select((state) => state.startup));
    final introFinished = ref.watch(startupIntroProvider);
    final auth = ref.read(authProvider.notifier);
    final cleanupFailed = startup == SessionStartup.cleanupFailed;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final showBrand =
        !introFinished ||
        startup == SessionStartup.checking ||
        startup == SessionStartup.ready;

    return Scaffold(
      backgroundColor: showBrand ? AppTheme.scaffoldBackgroundColor : null,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: showBrand
                ? _StartupBrand(
                    intro: introFinished || reduceMotion ? null : _intro,
                    checking:
                        introFinished && startup == SessionStartup.checking,
                    reduceMotion: reduceMotion,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cleanupFailed
                            ? 'No pudimos borrar la sesión guardada.'
                            : 'No pudimos verificar tu sesión.',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (!cleanupFailed)
                        const Text(
                          'Comprueba tu conexión y vuelve a intentarlo.',
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: cleanupFailed
                            ? () => auth.logout()
                            : auth.restore,
                        child: const Text('Reintentar'),
                      ),
                      if (!cleanupFailed)
                        TextButton(
                          onPressed: () => auth.logout(),
                          child: const Text('Borrar sesión e ir al ingreso'),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StartupBrand extends StatelessWidget {
  const _StartupBrand({
    required this.intro,
    required this.checking,
    required this.reduceMotion,
  });

  final Animation<double>? intro;
  final bool checking;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    const logoSize = 156.0;
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.asset(
        'resources/images/bankos_logo.png',
        width: logoSize,
        height: logoSize,
        cacheWidth: (logoSize * MediaQuery.devicePixelRatioOf(context)).ceil(),
        semanticLabel: 'BankOS',
      ),
    );
    final animation = intro;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.square(
          dimension: 280,
          child: Center(
            child: animation == null
                ? logo
                : AnimatedBuilder(
                    animation: animation,
                    child: logo,
                    builder: (context, child) {
                      final appearance = const Interval(
                        0,
                        4 / 7,
                        curve: Curves.easeOutCubic,
                      ).transform(animation.value);
                      final pulse = const Interval(
                        4 / 7,
                        1,
                      ).transform(animation.value);
                      final haloOpacity = pulse < 0.25
                          ? pulse * 4
                          : (1 - pulse) / 0.75;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          if (haloOpacity > 0)
                            Transform.scale(
                              scale: 1 + 0.35 * Curves.easeOut.transform(pulse),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      AppTheme.primaryColor.withValues(
                                        alpha: 0.32 * haloOpacity,
                                      ),
                                      AppTheme.primaryColor.withValues(
                                        alpha: 0,
                                      ),
                                    ],
                                    stops: const [0.35, 1],
                                  ),
                                ),
                                child: const SizedBox.square(dimension: 224),
                              ),
                            ),
                          Opacity(
                            opacity: appearance,
                            child: Transform.scale(
                              scale: 0.86 + 0.14 * appearance,
                              child: child,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
        if (checking)
          Positioned(
            bottom: 0,
            child: Column(
              spacing: 8,
              children: [
                if (reduceMotion)
                  const Icon(
                    Icons.hourglass_top_rounded,
                    size: 16,
                    color: AppTheme.primaryColor,
                  )
                else
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                Text(
                  'Verificando sesión…',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppTheme.textSecondaryColor),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
