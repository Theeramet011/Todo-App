// EditProfileScreen - หน้าจอแก้ไขโปรไฟล์ผู้ใช้งาน (Edit Profile)
//
// ให้ผู้ใช้แก้ไขข้อมูลส่วนตัว เช่น ชื่อ อัปโหลดรูปโปรไฟล์ และเลือกกรอบรูปโปรไฟล์ (Avatar Frame)
// พร้อมระบบบันทึกและอัปเดตข้อมูลไปยังระบบ Firebase
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/colors.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../widgets/frame_picker_widget.dart';
import '../widgets/user_avatar_with_frame.dart';
import '../providers/connectivity_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _isSaving = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameController.text = user?.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: isDark ? AppColors.stormyNightBackground : null,
      appBar: AppBar(
        title: Text(
          'แก้ไขโปรไฟล์',
          style: TextStyle(
            fontSize: isTablet ? 26 : null,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: isTablet ? 28 : 24),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: isDark ? AppColors.stormyNightBackground : null,
        scrolledUnderElevation: 0,
      ),
      body: user == null
          ? const Center(child: Text('No user data'))
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 32 : AppConstants.paddingLarge,
                  vertical: isTablet ? 32 : AppConstants.paddingLarge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAvatarSection(user, isTablet),
                    SizedBox(height: isTablet ? 32 : AppConstants.paddingXLarge),
                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        color: isDark ? Colors.white : null,
                      ),
                      decoration: InputDecoration(
                        labelText: 'ชื่อที่แสดง',
                        labelStyle: TextStyle(
                          fontSize: isTablet ? 17 : 14,
                          color: isDark ? AppColors.stormyMutedBlueGrey : null,
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline,
                          size: isTablet ? 26 : 22,
                          color: isDark ? AppColors.stormyMutedBlueGrey : null,
                        ),
                        contentPadding: isTablet
                            ? const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 20,
                              )
                            : null,
                        fillColor: isDark ? AppColors.stormyDarkSlate : null,
                        filled: isDark ? true : false,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMedium,
                          ),
                          borderSide: isDark
                              ? BorderSide.none
                              : const BorderSide(),
                        ),
                      ),
                    ),
                    SizedBox(height: isTablet ? 20 : AppConstants.paddingLarge),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.stormyDarkSlate
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusLarge,
                        ),
                        border: isDark
                            ? null
                            : Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                      ),
                      child: ListTile(
                        contentPadding: isTablet
                            ? const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              )
                            : null,
                        leading: Icon(
                          Icons.filter_frames_outlined,
                          size: isTablet ? 28 : 24,
                          color: isDark ? AppColors.stormyMutedBlueGrey : null,
                        ),
                        title: Text(
                          'เลือกกรอบโปรไฟล์',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : null,
                          ),
                        ),
                        subtitle: Text(
                          user.equippedFrame.isEmpty
                              ? 'ไม่ได้ใส่กรอบ'
                              : ProfileFrameStyle.fromId(
                                  user.equippedFrame,
                                ).label,
                          style: TextStyle(
                            fontSize: isTablet ? 15 : 13,
                            color: isDark
                                ? AppColors.stormyMutedBlueGrey
                                : null,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: isTablet ? 28 : 24,
                          color: isDark ? AppColors.stormyMutedBlueGrey : null,
                        ),
                        onTap: () => _openFramePicker(user),
                      ),
                    ),
                    SizedBox(height: isTablet ? 32 : AppConstants.paddingXLarge),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.stormySkyBlue,
                        foregroundColor: isDark
                            ? AppColors.stormyNightBackground
                            : AppColors.textWhite,
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 18 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMedium,
                          ),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textWhite,
                              ),
                            )
                          : Text(
                              'บันทึก',
                              style: TextStyle(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection(User user, bool isTablet) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatarWithFrame(
            avatarUrl: user.avatarUrl,
            frameId: user.equippedFrame,
            fallbackName: user.name,
            size: isTablet ? 160 : 128,
          ),
          if (_isUploadingImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.textWhite,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Material(
              color: AppColors.stormySkyBlue,
              shape: const CircleBorder(),
              child: InkWell(
                enableFeedback: false,
                customBorder: const CircleBorder(),
                onTap: _isUploadingImage ? null : _pickProfileImage,
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 14 : 10),
                  child: Icon(
                    Icons.camera_alt,
                    color: isDark
                        ? AppColors.stormyNightBackground
                        : AppColors.textWhite,
                    size: isTablet ? 24 : 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );

    if (pickedFile == null || !mounted) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final file = File(pickedFile.path);
      final ext = pickedFile.path.split('.').last;
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars')
          .child('${user.id}.$ext');

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      if (!mounted) return;

      await context.read<AuthProvider>().updateProfileInfo(
        name: _nameController.text.trim().isEmpty
            ? user.name
            : _nameController.text,
        avatarUrl: downloadUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถเปลี่ยนรูปโปรไฟล์ได้')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _openFramePicker(User user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark
          ? AppColors.stormyNightBackground
          : Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FramePickerWidget(user: user),
    );
  }

  Future<void> _saveProfile() async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await context.read<AuthProvider>().updateProfileInfo(
        name: _nameController.text,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถบันทึกโปรไฟล์ได้')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
