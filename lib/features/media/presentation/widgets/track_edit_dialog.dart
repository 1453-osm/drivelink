import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/app/theme/colors.dart';
import 'package:drivelink/core/database/database.dart';
import 'package:drivelink/features/media/data/media_repository.dart';
import 'package:drivelink/features/media/providers/media_providers.dart';

/// Dialog for editing a track's title, artist, album, and cover art.
class TrackEditDialog extends ConsumerStatefulWidget {
  const TrackEditDialog({super.key, required this.track});

  final MediaTrack track;

  static Future<bool?> show(BuildContext context, MediaTrack track) {
    return showDialog<bool>(
      context: context,
      builder: (_) => TrackEditDialog(track: track),
    );
  }

  @override
  ConsumerState<TrackEditDialog> createState() => _TrackEditDialogState();
}

class _TrackEditDialogState extends ConsumerState<TrackEditDialog> {
  late final TextEditingController _titleCtl;
  late final TextEditingController _artistCtl;
  String? _artUri;
  int? _albumId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtl = TextEditingController(text: widget.track.title);
    _artistCtl = TextEditingController(text: widget.track.artist);
    _artUri = widget.track.artUri;
    _albumId = widget.track.albumId;
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _artistCtl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _artUri = path);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(mediaRepositoryProvider);
    await repo.updateTrack(
      widget.track.id,
      title: _titleCtl.text.trim(),
      artist: _artistCtl.text.trim(),
      artUri: _artUri,
      clearArtUri: _artUri == null || _artUri!.isEmpty,
      albumId: _albumId,
      clearAlbumId: _albumId == null,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(albumsProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Parcayi Duzenle',
          style: TextStyle(color: AppColors.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickCover,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    image: _coverImage(),
                  ),
                  child: _artUri == null || !File(_artUri!).existsSync()
                      ? Icon(Icons.add_photo_alternate,
                          color: AppColors.textDisabled, size: 40)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: _pickCover,
                icon: const Icon(Icons.image, size: 16),
                label: const Text('Kapak Sec'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _textField(_titleCtl, 'Parca Adi'),
            const SizedBox(height: 12),
            _textField(_artistCtl, 'Sanatci'),
            const SizedBox(height: 12),
            albumsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (albums) => DropdownButtonFormField<int?>(
                initialValue: _albumId,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Album',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('(Albumsuz)',
                        style: TextStyle(color: AppColors.textDisabled)),
                  ),
                  ...albums.map((a) => DropdownMenuItem<int?>(
                        value: a.id,
                        child: Text(a.name,
                            overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => setState(() => _albumId = v),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: Text('Iptal',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text('Kaydet',
              style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }

  DecorationImage? _coverImage() {
    final uri = _artUri;
    if (uri == null || uri.isEmpty) return null;
    final file = File(uri);
    if (!file.existsSync()) return null;
    return DecorationImage(image: FileImage(file), fit: BoxFit.cover);
  }

  Widget _textField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
