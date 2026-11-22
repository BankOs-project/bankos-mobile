import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../auth/domain/models/auth_models.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(ref.watch(dioProvider)),
);

final myProfileProvider = FutureProvider.autoDispose
    .family<UserProfile, AuthSession>((ref, session) {
      final cancel = CancelToken();
      ref.onDispose(cancel.cancel);
      return ref.watch(profileRepositoryProvider).getProfile(session, cancel);
    }, retry: (_, _) => null);

final profilePhotoProvider = FutureProvider.autoDispose
    .family<ui.Image?, AuthSession>((ref, session) async {
      final cancel = CancelToken();
      ui.Image? image;
      ref.onDispose(() {
        cancel.cancel();
        image?.dispose();
      });
      final bytes = await ref
          .watch(profileRepositoryProvider)
          .getPhoto(session, cancel);
      if (bytes == null || !ref.mounted) return null;
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 256,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        if (!ref.mounted) {
          frame.image.dispose();
          return null;
        }
        return image = frame.image;
      } finally {
        codec.dispose();
      }
    }, retry: (_, _) => null);

final profileFilePickerProvider = Provider<Future<XFile?> Function()>((ref) {
  return () => openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'JPEG y PNG',
        extensions: ['jpg', 'jpeg', 'png'],
        mimeTypes: ['image/jpeg', 'image/png'],
        uniformTypeIdentifiers: ['public.jpeg', 'public.png'],
      ),
    ],
  );
});

final pendingProfileEmailProvider =
    NotifierProvider<ProfileEmailState, PendingProfileEmail?>(
      ProfileEmailState.new,
    );

class ProfileEmailState extends Notifier<PendingProfileEmail?> {
  @override
  PendingProfileEmail? build() {
    ref.watch(activeSessionProvider);
    return null;
  }

  void setPending(PendingProfileEmail value) => state = value;

  void clearPending() => state = null;
}
