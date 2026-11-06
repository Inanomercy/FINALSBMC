import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/authentication/providers/auth_provider.dart';
import '../../../shared/providers/cart_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/ocean_text_field.dart';
import '../../../core/utils/validators.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.userProfile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My Profile'), backgroundColor: AppColors.primary, automaticallyImplyLeading: false),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                        child: profile.avatarUrl == null
                            ? Text(profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.primary))
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: Text(profile.fullName, style: Theme.of(context).textTheme.headlineMedium)),
                Center(child: Text(profile.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                const SizedBox(height: 24),

                // Profile Info Card
                _MenuCard(
                  children: [
                    _MenuItem(icon: Icons.person_outline, title: 'Edit Profile', onTap: () => _showEditProfile(context)),
                    _MenuItem(icon: Icons.lock_outline, title: 'Change Password', onTap: () => _showChangePassword(context)),
                    _MenuItem(icon: Icons.location_on_outlined, title: 'Delivery Addresses', subtitle: profile.address, onTap: () {}),
                    _MenuItem(icon: Icons.phone_outlined, title: 'Contact Number', subtitle: profile.phone, onTap: () {}),
                  ],
                ),
                const SizedBox(height: 16),
                _MenuCard(
                  children: [
                    _MenuItem(icon: Icons.receipt_long_outlined, title: 'Order History', onTap: () => context.go('/customer/orders')),
                    _MenuItem(icon: Icons.help_outline, title: 'Help & Support', onTap: () {}),
                    _MenuItem(icon: Icons.info_outline, title: 'About OceanCart', onTap: () {}),
                  ],
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Sign Out',
                  color: AppColors.error,
                  icon: Icons.logout,
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content: const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Sign Out', style: TextStyle(color: AppColors.error))),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      context.read<CartProvider>().clearLocal();
                      await context.read<AuthProvider>().logout();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    }
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  void _showEditProfile(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final nameCtrl = TextEditingController(text: auth.userProfile?.fullName);
    final phoneCtrl = TextEditingController(text: auth.userProfile?.phone);
    final addressCtrl = TextEditingController(text: auth.userProfile?.address);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Profile', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            OceanTextField(controller: nameCtrl, label: 'Full Name', prefixIcon: Icons.person_outline),
            const SizedBox(height: 12),
            OceanTextField(controller: phoneCtrl, label: 'Phone', prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            OceanTextField(controller: addressCtrl, label: 'Delivery Address', prefixIcon: Icons.location_on_outlined, maxLines: 2),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save Changes',
              onPressed: () async {
                await auth.updateProfile(fullName: nameCtrl.text, phone: phoneCtrl.text, address: addressCtrl.text);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change Password', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            OceanTextField(controller: newPassCtrl, label: 'New Password', prefixIcon: Icons.lock_outline, obscureText: true, validator: Validators.password),
            const SizedBox(height: 12),
            OceanTextField(controller: confirmCtrl, label: 'Confirm Password', prefixIcon: Icons.lock_outline, obscureText: true),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Update Password',
              onPressed: () async {
                if (newPassCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                  return;
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6)]),
    child: Column(children: children),
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.grey),
      onTap: onTap,
    );
  }
}
