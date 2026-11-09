import 'package:flutter/material.dart';

import '../core/user_shell_theme.dart';
import '../services/profile_photo_service.dart';

/// Round profile picture. Shows a person icon when there is no photo, while
/// loading, or if the photo cannot be shown.
class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.path,
    this.size = 64,
    this.background = kGreen,
    this.loadUrl,
  });

  final String? path;
  final double size;
  final Color background;

  /// For tests; defaults to [ProfilePhotoService.viewUrl].
  final Future<String?> Function(String? path)? loadUrl;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Future<String?>? _url;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  void _load() {
    final path = widget.path?.trim() ?? '';
    if (path.isEmpty) {
      _url = null;
      return;
    }
    final loader =
        widget.loadUrl ?? ((String? p) => ProfilePhotoService().viewUrl(p));
    _url = loader(path).catchError((Object _) => null);
  }

  Widget _icon() => Icon(
        Icons.person,
        color: Colors.white,
        size: widget.size * 0.56,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('profile-avatar'),
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.background, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: _url == null
          ? _icon()
          : FutureBuilder<String?>(
              future: _url,
              builder: (context, snap) {
                final url = snap.data;
                if (url == null) return _icon();
                return Image.network(
                  url,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _icon(),
                );
              },
            ),
    );
  }
}
