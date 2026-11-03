import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/widgets/custom_button.dart';
import 'package:starq_app/core/widgets/custom_text_field.dart';
import 'package:starq_app/core/widgets/starq_logo.dart';
import 'package:starq_app/core/utils/validators.dart';
import 'package:starq_app/features/models/address_model.dart';
import 'package:starq_app/features/providers/address_provider.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/features/addresses/domain/address.dart' as addr_domain;

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchAddresses();
      }
    });
  }

  Future<void> _fetchAddresses() async {
    final authId = context.read<AuthProvider?>()?.currentUser?.id;
    final prov = context.read<AddressProvider>();
    if (authId != null && authId.isNotEmpty) {
      prov.setCurrentUserId(authId);
    }
    await prov.fetchAddresses(authId);
  }

  Future<void> _navigateToAddAddress() async {
    await context.push('/add-address');
    if (mounted) {
      await _fetchAddresses();
    }
  }

  Future<void> _setAsDefault(Address addr) async {
    final authId = context.read<AuthProvider?>()?.currentUser?.id;
    await context.read<AddressProvider>().setDefaultAddress(addr, authId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Set "${addr.displayTitle}" as default address'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  void _onAddressSelected(Address addr, AddressProvider provider) {
    final authId = context.read<AuthProvider?>()?.currentUser?.id;
    provider.selectAddress(addr, authId);
    try {
      final bookingAddr = addr_domain.Address(
        id: addr.id,
        userId: addr.userId,
        label: addr.displayTitle,
        addressLine: addr.line1,
        city: addr.city,
        state: addr.state ?? 'Uttar Pradesh',
        pincode: addr.zipCode ?? '',
        latitude: addr.latitude ?? 28.6270,
        longitude: addr.longitude ?? 77.3649,
        isDefault: provider.isDefaultAddress(addr),
      );
      context.read<BookingFlowProvider>().setAddress(bookingAddr);
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected "${addr.displayTitle}" as active address'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmDelete(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Address', style: AppTextStyles.subheading),
        content: Text(
          'Are you sure you want to remove "${address.displayTitle}"?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTextStyles.body.copyWith(color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authId = context.read<AuthProvider?>()?.currentUser?.id;
      final success = await context.read<AddressProvider>().deleteAddress(address.id, authId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Address removed' : 'Failed to remove address',
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
            backgroundColor: success ? Colors.black87 : Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _showEditAddressModal(Address address) {
    final labelCtrl = TextEditingController(text: address.displayTitle);
    final lineCtrl = TextEditingController(text: address.line1);
    final landmarkCtrl = TextEditingController(text: address.landmark ?? '');
    final cityCtrl = TextEditingController(text: address.city);
    final pinCtrl = TextEditingController(text: address.zipCode ?? '');
    String? lineError;
    String? pinError;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit Address', style: AppTextStyles.heading.copyWith(fontSize: 20)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  hintText: 'Label (e.g. Home, Work, Office)',
                  controller: labelCtrl,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  hintText: 'House / Flat / Street / Area',
                  controller: lineCtrl,
                  errorText: lineError,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  hintText: 'Landmark (Optional)',
                  controller: landmarkCtrl,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        hintText: 'City',
                        controller: cityCtrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        hintText: '6-digit PIN code',
                        controller: pinCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        errorText: pinError,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AppButton(
                  text: 'Save Changes',
                  isLoading: isSaving,
                  onPressed: () async {
                    if (isSaving) return;
                    final line = lineCtrl.text.trim();
                    final pin = pinCtrl.text.trim();

                    setModalState(() {
                      lineError = line.isEmpty ? 'Address is required' : null;
                      pinError = AppValidators.pincode(pin);
                    });

                    if (lineError != null || pinError != null) return;

                    setModalState(() => isSaving = true);
                    final authId = context.read<AuthProvider?>()?.currentUser?.id;
                    final addressProvider = context.read<AddressProvider>();

                    final landmarkText = landmarkCtrl.text.trim();
                    final line1Val = landmarkText.isNotEmpty ? '$line, Near $landmarkText' : line;

                    final success = await addressProvider.updateAddress(
                      address.id,
                      {
                        'line1': line1Val,
                        'line2': labelCtrl.text.trim().isNotEmpty ? labelCtrl.text.trim() : 'Home',
                        'city': cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : 'Noida',
                        'state': address.state ?? 'Uttar Pradesh',
                        'zipCode': pin,
                        'latitude': address.latitude,
                        'longitude': address.longitude,
                      },
                      authId,
                    );

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }

                    if (mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Address updated successfully!'),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(addressProvider.error ?? 'Failed to update address'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pageBgColor = Color(0xFFFAF2F4); // Soft off-white / very light pink background

    return Scaffold(
      backgroundColor: pageBgColor,
      body: SafeArea(
        child: Consumer<AddressProvider>(
          builder: (context, provider, _) {
            final authId = context.read<AuthProvider?>()?.currentUser?.id;

            return RefreshIndicator(
              onRefresh: () => provider.fetchAddresses(authId),
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Bar row with Back Arrow and Centered STARQ Logo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: AppColors.textDark, size: 24),
                              onPressed: () => context.pop(),
                            ),
                          ),
                          const Center(
                            child: StarqLogo(height: 26),
                          ),
                        ],
                      ),
                    ),

                    // Heading and Subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved Addresses',
                            style: AppTextStyles.heading.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your service locations',
                            style: AppTextStyles.body.copyWith(
                              fontSize: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Large white rounded container holding the address cards
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Non-blocking error banner if addresses exist but background sync failed
                          if (provider.error != null && provider.addresses.isNotEmpty) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 18, color: Colors.red.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      provider.error!,
                                      style: TextStyle(fontSize: 12, color: Colors.red.shade900),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => provider.fetchAddresses(authId),
                                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // State 1: Loading
                          if (provider.isLoading && provider.addresses.isEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 60),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: AppColors.primary),
                                    SizedBox(height: 16),
                                    Text(
                                      'Loading saved addresses...',
                                      style: TextStyle(color: AppColors.textLight, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]
                          // State 2: API Failure (Never show empty state on API error!)
                          else if (provider.error != null && provider.addresses.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Icon(
                                        Icons.error_outline,
                                        size: 32,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text('Failed to Load Addresses', style: AppTextStyles.subheading),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        provider.error!,
                                        style: AppTextStyles.body.copyWith(color: AppColors.textLight),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    OutlinedButton.icon(
                                      onPressed: () => provider.fetchAddresses(authId),
                                      icon: const Icon(Icons.refresh, size: 18),
                                      label: const Text('Try Again'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]
                          // State 3: Empty State
                          else if (provider.addresses.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFECEF),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.primaryLight),
                                      ),
                                      child: const Icon(
                                        Icons.location_off_outlined,
                                        size: 32,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text('No Saved Addresses Yet', style: AppTextStyles.subheading),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        'Add your home or work address for faster service booking.',
                                        style: AppTextStyles.body.copyWith(color: AppColors.textLight),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]
                          // State 4: Addresses Available
                          else ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                'SAVED ADDRESSES (${provider.addresses.length})',
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),

                            // List of address cards
                            ...provider.addresses.map((addr) {
                              final isDefault = provider.isDefaultAddress(addr);
                              final isSelected = addr.id == provider.selectedAddress?.id;

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFFFF9FA) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                                    width: isSelected ? 1.5 : 1.2,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.08),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: InkWell(
                                  onTap: () => _onAddressSelected(addr, provider),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Light pink square icon background with a red location-pin icon
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFECEF), // light pink
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: AppColors.primary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Address text details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                // Address label in bold (e.g. Home, Work)
                                                Flexible(
                                                  child: Text(
                                                    addr.displayTitle,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.textDark,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // Red/pink "Default" badge for the default address
                                                if (isDefault) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFEBEE),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      'Default',
                                                      style: TextStyle(
                                                        color: AppColors.primary,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            // Full saved address displayed below the label in readable grey text
                                            Text(
                                              addr.fullAddress,
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 13,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // Circular radio selection indicator on the right side
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                            width: 2.0,
                                          ),
                                          color: isSelected ? AppColors.primary : Colors.transparent,
                                        ),
                                        child: Center(
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            curve: Curves.easeInOut,
                                            width: isSelected ? 8 : 0,
                                            height: isSelected ? 8 : 0,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Three-dot menu on the right of each address
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: Colors.grey.shade600,
                                          size: 20,
                                        ),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            _showEditAddressModal(addr);
                                          } else if (val == 'default') {
                                            _setAsDefault(addr);
                                          } else if (val == 'delete') {
                                            _confirmDelete(addr);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 18, color: AppColors.textDark),
                                                SizedBox(width: 10),
                                                Text('Edit Address'),
                                              ],
                                            ),
                                          ),
                                          if (!isDefault)
                                            const PopupMenuItem(
                                              value: 'default',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.check_circle_outline, size: 18, color: AppColors.primary),
                                                  SizedBox(width: 10),
                                                  Text('Set as Default'),
                                                ],
                                              ),
                                            ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                SizedBox(width: 10),
                                                Text('Delete Address', style: TextStyle(color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],

                          const SizedBox(height: 12),

                          // Large outlined red "＋ Add New Address" button at the bottom of the white container
                          OutlinedButton.icon(
                            onPressed: _navigateToAddAddress,
                            icon: const Icon(Icons.add, color: AppColors.primary, size: 20),
                            label: const Text(
                              'Add New Address',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              side: const BorderSide(color: AppColors.primary, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
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
