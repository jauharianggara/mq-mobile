import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/mq_api.dart';
import '../theme/app_theme.dart';

/// Avatar dengan foto (URL presigned) + fallback inisial berwarna.
/// Dipakai lintas layar: profil, pilih ustadz, thread.
class MqAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? name;
  final double radius;
  final double? fontSize;

  const MqAvatar({super.key, this.photoUrl, this.name, this.radius = 20, this.fontSize});

  String get _initial {
    final n = (name ?? '').trim();
    if (n.isEmpty) return '?';
    return n.characters.first.toUpperCase();
  }

  Color get _bg {
    // warna stabil dari hash nama — biar tiap orang konsisten
    var h = 0;
    for (final c in (name ?? '?').codeUnits) {
      h = (h * 31 + c) & 0xffffff;
    }
    final hue = (h % 360).toDouble();
    return HSLColor.fromAHSL(1, hue, 0.45, 0.85).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final url = (photoUrl ?? '').trim();
    final size = radius * 2;
    if (url.isEmpty) return _plain();
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _plain(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : SizedBox(width: size, height: size, child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))),
      ),
    );
  }

  Widget _plain() => CircleAvatar(
        radius: radius,
        backgroundColor: _bg,
        child: Text(
          _initial,
          style: TextStyle(
            fontSize: fontSize ?? radius * 0.8,
            color: HSLColor.fromColor(_bg).withLightness(0.3).toColor(),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

/// Bottom sheet pilih sumber foto avatar + upload presign + PATCH /me.
/// [onChanged] dipanggil setelah foto berhasil diganti/dihapus.
Future<void> showAvatarPicker(
  BuildContext context,
  MqApi api, {
  required VoidCallback onChanged,
  bool hasPhoto = false,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil Foto'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pilih dari Galeri'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          if (hasPhoto)
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: Text('Hapus Foto', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null) return;

  try {
    if (choice == 'remove') {
      await api.patchMe({'remove_photo': true});
      onChanged();
      return;
    }
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final mime = x.mimeType ?? 'image/jpeg';
    final mediaId = await api.uploadImageBytes(bytes, mime);
    if (mediaId != null) {
      await api.patchMe({'photo_media_id': mediaId});
      onChanged();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, 'Upload foto gagal — coba lagi'))),
      );
    }
  }
}
