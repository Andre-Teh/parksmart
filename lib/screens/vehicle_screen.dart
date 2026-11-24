import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parksmart/core/theme.dart';

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final _plateController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String _selectedVehicleType = 'sedan';

  final List<Map<String, dynamic>> _vehicleTypes = [
    {'id': 'none', 'label': 'None (Default)', 'image': ''},
    {
      'id': 'toothless',
      'label': 'Toothless',
      'image': 'assets/cars/toothless.png',
    },
    {'id': 'gru', 'label': 'Gru', 'image': 'assets/cars/gru.png'},
    {
      'id': 'ghostrider',
      'label': 'Ghost Rider',
      'image': 'assets/cars/ghostrider.png',
    },
    {'id': 'ufo', 'label': 'UFO', 'image': 'assets/cars/ufo.png'},
  ];

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      final vehicle = data['vehicle'] as Map<String, dynamic>? ?? {};
      setState(() {
        _plateController.text = vehicle['plate'] as String? ?? '';
        _selectedVehicleType = vehicle['type'] as String? ?? 'sedan';
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveVehicle() async {
    if (_plateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your plate number'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'vehicle': {
          'plate': _plateController.text.trim().toUpperCase(),
          'type': _selectedVehicleType,
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle saved successfully!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save vehicle. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _selectedImage {
    if (_selectedVehicleType == 'none') return '';
    return _vehicleTypes.firstWhere(
          (v) => v['id'] == _selectedVehicleType,
          orElse: () => _vehicleTypes.first,
        )['image']
        as String;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Vehicle',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vehicle preview
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha:0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha:0.3),
                              width: 3,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _selectedVehicleType == 'none'
                                ? const Icon(
                                    Icons.location_on_rounded,
                                    color: AppColors.primary,
                                    size: 48,
                                  )
                                : Image.asset(
                                    _selectedImage,
                                    fit: BoxFit.contain,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.directions_car_rounded,
                                      color: AppColors.primary,
                                      size: 48,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_plateController.text.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha:0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha:0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              _plateController.text.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          'This is how your vehicle appears on the map',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Plate number
                  const Text(
                    'Plate Number',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _plateController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'e.g. WXX 1234',
                      prefixIcon: Icon(
                        Icons.confirmation_number_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Vehicle icon selection
                  const Text(
                    'Choose Your Icon',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This icon will appear on the map',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: _vehicleTypes.map((type) {
                      final isSelected = _selectedVehicleType == type['id'];
                      return GestureDetector(
                        onTap: () => setState(
                          () => _selectedVehicleType = type['id'] as String,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primarySurface
                                : Theme.of(context).brightness ==
                                      Brightness.dark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey.withValues(alpha:0.2),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha:
                                        0.15,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: type['id'] == 'none'
                                      ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.location_on_rounded,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : Colors.grey[400],
                                              size: 32,
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                        )
                                      : Image.asset(
                                          type['image'] as String,
                                          fit: BoxFit.contain,
                                          errorBuilder: (c, e, s) => const Icon(
                                            Icons.directions_car_rounded,
                                            color: AppColors.primary,
                                            size: 32,
                                          ),
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 4,
                                  left: 4,
                                  right: 4,
                                ),
                                child: Text(
                                  type['label'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isSaving ? null : _saveVehicle,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Vehicle',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
