import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../rank/domain/xp_rules.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.auth.profile?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 82,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ok = await widget.auth.uploadAvatar(bytes);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.auth.errorMessage ?? 'Не удалось загрузить фото'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Имя слишком короткое')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final ok = await widget.auth.saveDisplayName(name);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.auth.errorMessage ?? 'Не удалось сохранить'),
          ),
        );
        return;
      }
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.auth,
      builder: (context, _) {
        final profile = widget.auth.profile;
        return Scaffold(
          appBar: AppBar(title: const Text('Профиль')),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      UserAvatar(
                        photoUrl: profile?.photoUrl,
                        name: _nameController.text.isEmpty
                            ? profile?.displayName
                            : _nameController.text,
                        rankId: profile == null
                            ? null
                            : XpRules.rankForXp(profile.xp),
                        size: 96,
                        previewOnTap: true,
                      ),
                      if (_uploading)
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _uploading ? null : _pickAvatar,
                  child: Text(_uploading ? 'Загружаем…' : 'Сменить аватар'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Отображаемое имя',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 8),
                Text(
                  profile?.email ?? '',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.background,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_saving ? 'Сохраняем…' : 'Сохранить имя'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
