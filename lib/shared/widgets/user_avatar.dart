import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/rank/presentation/rank_badge.dart';

ImageProvider? userPhotoProvider(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final value = url.trim();
  if (value.startsWith('data:')) {
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    try {
      return MemoryImage(base64Decode(value.substring(comma + 1)));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(value);
}

Future<void> showUserPhotoPreview(
  BuildContext context, {
  required String? photoUrl,
  String? name,
}) {
  final image = userPhotoProvider(photoUrl);
  if (image == null) return Future.value();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, _) {
        return FadeTransition(
          opacity: animation,
          child: _UserPhotoPreview(image: image, name: name),
        );
      },
    ),
  );
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.photoUrl,
    this.name,
    this.rankId,
    this.size = 48,
    this.onTap,
    this.previewOnTap = false,
  });

  final String? photoUrl;
  final String? name;
  final String? rankId;
  final double size;
  final VoidCallback? onTap;
  final bool previewOnTap;

  String get _initials {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    String take(String value, int n) =>
        String.fromCharCodes(value.runes.take(n));
    if (parts.length == 1) return take(parts.first, 2).toUpperCase();
    return '${take(parts.first, 1)}${take(parts.last, 1)}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final image = userPhotoProvider(photoUrl);
    final hasPhoto = image != null;
    final badgeSize = (size * 0.42).clamp(16.0, 22.0);

    final face = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.55),
          width: 1.5,
        ),
        image: hasPhoto
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Text(
              _initials,
              style: TextStyle(
                color: AppColors.amber,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.32,
              ),
            ),
    );

    final content = rankId == null
        ? face
        : SizedBox(
            width: size + 4,
            height: size + 4,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                face,
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: RankBadge(rankId: rankId!, size: badgeSize),
                ),
              ],
            ),
          );

    final handler = onTap ??
        (previewOnTap && hasPhoto
            ? () => showUserPhotoPreview(
                  context,
                  photoUrl: photoUrl,
                  name: name,
                )
            : null);
    if (handler == null) return content;
    return GestureDetector(onTap: handler, child: content);
  }
}

class _UserPhotoPreview extends StatelessWidget {
  const _UserPhotoPreview({required this.image, this.name});

  final ImageProvider image;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 72),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: GestureDetector(
                      onTap: () {},
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image(
                          image: image,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (name != null && name!.trim().isNotEmpty)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Text(
                    name!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
