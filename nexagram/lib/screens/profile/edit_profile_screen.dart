import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/validators.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../theme/theme.dart';
import '../../widgets/common/glass_text_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/user_avatar.dart';

/// Edits the signed-in user's `name`, `bio`, `phoneNumber`, and avatar.
///
/// Username and email are intentionally not editable here: username
/// changes would require re-running the uniqueness reservation dance in
/// [AuthService.register], and email changes need Firebase Auth
/// re-verification — both are bigger flows than this screen's scope.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _phoneController;

  File? _pendingAvatar;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final UserModel user = context.read<AuthProvider>().currentUser!;
    _nameController = TextEditingController(text: user.name);
    _bioController = TextEditingController(text: user.bio);
    _phoneController = TextEditingController(text: user.phoneNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: AppConstants.avatarCompressQuality,
    );
    if (file == null) return;
    setState(() => _pendingAvatar = File(file.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final UserModel user = context.read<AuthProvider>().currentUser!;

    setState(() => _isSaving = true);
    try {
      String? avatarUrl;
      if (_pendingAvatar != null) {
        avatarUrl = await _storageService.uploadAvatar(
          user.uid,
          _pendingAvatar!,
        );
      }
      await _userService.updateProfile(
        uid: user.uid,
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        avatarUrl: avatarUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your profile.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserModel user = context.watch<AuthProvider>().currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.lg),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    _pendingAvatar != null
                        ? ClipOval(
                            child: Image.file(
                              _pendingAvatar!,
                              width: 112,
                              height: 112,
                              fit: BoxFit.cover,
                            ),
                          )
                        : UserAvatar(
                            seed: user.uid,
                            avatarUrl: user.avatarUrl,
                            initials: user.initials,
                            radius: 56,
                          ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.xxl),
            AppTextField(
              controller: _nameController,
              label: 'Name',
              prefixIcon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              validator: Validators.name,
            ),
            const SizedBox(height: AppDimens.md),
            AppTextField(
              controller: _bioController,
              label: 'Bio',
              prefixIcon: Icons.info_outline_rounded,
              maxLines: 3,
              maxLength: 150,
              validator: Validators.bio,
            ),
            const SizedBox(height: AppDimens.md),
            AppTextField(
              controller: _phoneController,
              label: 'Phone number',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: Validators.phoneNumber,
            ),
            const SizedBox(height: AppDimens.xxl),
            PrimaryButton(
              label: 'Save Changes',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
