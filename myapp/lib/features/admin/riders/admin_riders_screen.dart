import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/ocean_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../authentication/providers/auth_provider.dart';

class AdminRidersScreen extends StatefulWidget {
  const AdminRidersScreen({super.key});

  @override
  State<AdminRidersScreen> createState() => _AdminRidersScreenState();
}

class _AdminRidersScreenState extends State<AdminRidersScreen> {
  List<Map<String, dynamic>> _riders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRiders();
  }

  Future<void> _loadRiders() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.adminClient
          .from('profiles')
          .select()
          .eq('role', AppConstants.roleRider)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _riders = List<Map<String, dynamic>>.from(res as List);
          _loading = false;
        });
        return;
      }
    } catch (_) {
      try {
        final res = await SupabaseService.client
            .from('profiles')
            .select()
            .eq('role', AppConstants.roleRider)
            .order('created_at', ascending: false);
        if (mounted) {
          setState(() {
            _riders = List<Map<String, dynamic>>.from(res as List);
            _loading = false;
          });
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleRiderStatus(String id, bool currentStatus) async {
    try {
      await SupabaseService.adminClient
          .from('profiles')
          .update({'is_active': !currentStatus})
          .eq('id', id);
      await _loadRiders();
    } catch (e) {
      try {
        await SupabaseService.client
            .from('profiles')
            .update({'is_active': !currentStatus})
            .eq('id', id);
        await _loadRiders();
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating status: $e2'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  void _showAddRiderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRiderSheet(onRiderAdded: _loadRiders),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rider Management'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: _loadRiders,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRiderDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _riders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delivery_dining_outlined, size: 64, color: AppColors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'No riders found',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showAddRiderDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add First Rider'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRiders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _riders.length,
                    itemBuilder: (ctx, i) {
                      final rider = _riders[i];
                      final isActive = rider['is_active'] as bool? ?? true;

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                radius: 24,
                                child: const Icon(Icons.delivery_dining, color: AppColors.primary),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rider['full_name'] as String? ?? 'Rider',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      rider['email'] as String? ?? '',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                    Text(
                                      rider['phone'] as String? ?? 'No phone',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Switch(
                                    value: isActive,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: (_) => _toggleRiderStatus(rider['id'] as String, isActive),
                                  ),
                                  Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isActive ? AppColors.success : AppColors.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _AddRiderSheet extends StatefulWidget {
  final VoidCallback onRiderAdded;
  const _AddRiderSheet({required this.onRiderAdded});

  @override
  State<_AddRiderSheet> createState() => _AddRiderSheetState();
}

class _AddRiderSheetState extends State<_AddRiderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveRider() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      final auth = context.read<AuthProvider>();
      final ok = await auth.createRider(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );

      if (ok) {
        widget.onRiderAdded();
        if (!mounted) return;
        nav.pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Rider account created successfully!'), backgroundColor: AppColors.success),
        );
      } else {
        throw Exception(auth.errorMessage ?? 'Failed to create rider account');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Error creating rider: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add New Rider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 12),
              OceanTextField(
                controller: _nameCtrl,
                label: 'Full Name',
                validator: (v) => Validators.required(v, fieldName: 'Full name'),
              ),
              const SizedBox(height: 12),
              OceanTextField(
                controller: _emailCtrl,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const SizedBox(height: 12),
              OceanTextField(
                controller: _phoneCtrl,
                label: 'Phone Number',
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
              ),
              const SizedBox(height: 12),
              OceanTextField(
                controller: _passCtrl,
                label: 'Temporary Password',
                obscureText: true,
                validator: Validators.password,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Create Rider',
                isLoading: _saving,
                onPressed: _saveRider,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
