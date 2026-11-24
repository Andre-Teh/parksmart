import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parksmart/core/theme.dart';
import 'package:parksmart/models/parking_lot.dart';
import 'package:parksmart/screens/active_session_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parksmart/screens/home_screen.dart';
import 'dart:ui' as ui;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  int _selectedLotIndex = -1;
  LatLng _currentPosition = const LatLng(3.1575, 101.7450);
  bool _locationGranted = false;
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  String _activeSessionLotId = '';
  BitmapDescriptor? _vehicleMarkerIcon;

  StreamSubscription<QuerySnapshot>? _lotsSubscription;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  List<ParkingLot> _parkingLots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestLocation();
    _checkActiveSession();
    _loadVehicleData();
    vehicleUpdateNotifier.addListener(_onVehicleUpdate);
  }

  void _onVehicleUpdate() {
    _vehicleMarkerIcon = null;
    _loadVehicleData();
  }

  @override
  void dispose() {
    _lotsSubscription?.cancel();
    vehicleUpdateNotifier.removeListener(_onVehicleUpdate);
    _sheetController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkActiveSession();
    _loadVehicleData();
  }

  Map<String, dynamic> _vehicleData = {};

  Future<void> _loadVehicleData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      final data = doc.data() ?? {};
      final newVehicleData = data['vehicle'] as Map<String, dynamic>? ?? {};

      // Only rebuild marker if vehicle type changed
      final newType = newVehicleData['type'] as String? ?? '';
      final oldType = _vehicleData['type'] as String? ?? '';

      setState(() => _vehicleData = newVehicleData);

      if (newVehicleData.isNotEmpty && newType != oldType) {
        _vehicleMarkerIcon = null; // Clear old marker
        final marker = await _buildVehicleMarker();
        if (mounted) {
          setState(() => _vehicleMarkerIcon = marker);
        }
      } else if (newVehicleData.isNotEmpty && _vehicleMarkerIcon == null) {
        final marker = await _buildVehicleMarker();
        if (mounted) {
          setState(() => _vehicleMarkerIcon = marker);
        }
      }

      if (_vehicleData.isNotEmpty) {
        final type = _vehicleData['type'] as String? ?? 'none';
        if (type != 'none' && type.isNotEmpty) {
          final marker = await _buildVehicleMarker();
          if (mounted) {
            setState(() => _vehicleMarkerIcon = marker);
          }
        } else {
          setState(() => _vehicleMarkerIcon = null);
        }
      }
    }
  }


  Future<BitmapDescriptor> _buildVehicleMarker() async {
    final type = _vehicleData['type'] as String? ?? 'sedan';

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 140.0;

    // Light grey circle background
    final bgPaint = Paint()
      ..color = const Color.fromARGB(197, 98, 98, 98).withValues(alpha:0.5);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 20, bgPaint);

    // Load car image
    try {
      final byteData = await rootBundle.load('assets/cars/$type.png');
      final codec = await ui.instantiateImageCodec(
        byteData.buffer.asUint8List(),
        targetWidth: 130,
        targetHeight: 130,
      );
      final frame = await codec.getNextFrame();
      final carImage = frame.image;
      canvas.drawImage(
        carImage,
        const Offset((size - 130) / 2, (size - 130) / 2),
        Paint(),
      );
    } catch (e) {
      final iconPainter = TextPainter(textDirection: TextDirection.ltr);
      iconPainter.text = const TextSpan(
        text: '\ue531',
        style: TextStyle(
          fontSize: 90,
          fontFamily: 'MaterialIcons',
          color: AppColors.primary,
        ),
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset((size - iconPainter.width) / 2, (size - iconPainter.height) / 2),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    // ignore: deprecated_member_use
    return BitmapDescriptor.fromBytes(
      bytes!.buffer.asUint8List(),
      size: const Size(80, 80),
    );
  }

  // Load parking lots from Firestore in real-time
  void _listenToParkingLots() {
    _lotsSubscription = FirebaseFirestore.instance
        .collection('parking_lots')
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _parkingLots = snapshot.docs
                .map((doc) => ParkingLot.fromFirestore(doc))
                .toList();
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _checkActiveSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .get();
    if (snapshot.docs.isNotEmpty && mounted) {
      setState(() {
        _activeSessionLotId =
            snapshot.docs.first.data()['lotId'] as String? ?? '';
      });
    } else {
      setState(() => _activeSessionLotId = '');
    }
  }

  Future<void> _requestLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _listenToParkingLots();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      _getLocation();
      _listenToParkingLots();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      _listenToParkingLots();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Enable location in Settings to use live location.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 160,
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Allow ParkSmart to access\nyour location',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Your location is used to show nearby parking spots and help you navigate to them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ),
              const Divider(height: 0),
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  await Geolocator.requestPermission();
                  _getLocation();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Text(
                    'Allow While Using App',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const Divider(height: 0),
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  await Geolocator.requestPermission();
                  _getLocation();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: const Text(
                    'Allow Once',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const Divider(height: 0),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    "Don't Allow",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[500]),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      );
    }
    _listenToParkingLots();
  }

  Future<void> _getLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        setState(() => _locationGranted = true);
        final position = await Geolocator.getCurrentPosition(
          // ignore: deprecated_member_use
          desiredAccuracy: LocationAccuracy.high,
        );
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLng(_currentPosition),
          );
        }
      }
    } catch (e) {
      // Could not get position
    }
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Add parking lot markers
    for (final entry in _searchedLots.asMap().entries) {
      final index = entry.key;
      final lot = entry.value;

      BitmapDescriptor icon;
      if (lot.isFull) {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      } else if (lot.isFillingUp) {
        icon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      } else if (lot.isEv) {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      } else {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      }

      markers.add(
        Marker(
          markerId: MarkerId('lot_$index'),
          position: lot.position,
          icon: icon,
          infoWindow: InfoWindow(
            title: lot.name,
            snippet: '${lot.available} spots available · ${lot.rate}',
          ),
          onTap: () {
            final originalIndex = _parkingLots.indexOf(lot);
            setState(() => _selectedLotIndex = originalIndex);
            _sheetController.animateTo(
              0.55,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          },
        ),
      );
    }

    // Add vehicle marker at current location
    // Add vehicle marker
    // Add vehicle marker
    if (_locationGranted && _vehicleData.isNotEmpty) {
      final type = _vehicleData['type'] as String? ?? 'none';

      if (type == 'none' || type.isEmpty) {
        // Show default Google Maps blue dot
        // Just enable myLocationEnabled instead
      } else {
        markers.add(
          Marker(
            markerId: const MarkerId('my_vehicle'),
            position: _currentPosition,
            icon:
                _vehicleMarkerIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen,
                ),
            infoWindow: InfoWindow(
              title: _vehicleData['plate'] as String? ?? 'My Vehicle',
            ),
            // ignore: deprecated_member_use
            zIndex: 99,
            anchor: const Offset(0.5, 0.5),
          ),
        );
      }
    }
    return markers;
  }

  Color _getStatusColor(int available, int total) {
    if (available == 0) return AppColors.error;
    if (available / total < 0.3) return AppColors.warning;
    return AppColors.primary;
  }

  String _getStatusText(int available) {
    if (available == 0) return 'Full';
    if (available <= 3) return '$available left';
    return '$available free';
  }

  int get _totalAvailable =>
      _parkingLots.fold(0, (acc, lot) => acc + lot.available);

  int get _fillingUp =>
      _parkingLots.where((lot) => lot.isFillingUp).length;

  int get _fullCount =>
      _parkingLots.where((lot) => lot.isFull).length;

  List<ParkingLot> get _filteredLots {
    switch (_selectedFilter) {
      case 'EV Charging':
        return _parkingLots.where((lot) => lot.isEv).toList();
      case 'Available':
        return _parkingLots.where((lot) => lot.available > 0).toList();
      case 'Covered':
        return _parkingLots.where((lot) => lot.type == 'parking').toList();
      default:
        return _parkingLots;
    }
  }

  List<ParkingLot> get _searchedLots {
    final filtered = _filteredLots;
    if (_searchQuery.isEmpty) return filtered;
    return filtered.where((lot) {
      final query = _searchQuery.toLowerCase();
      return lot.name.toLowerCase().contains(query) ||
          lot.address.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 15,
            ),
            markers: _buildMarkers(),
            myLocationEnabled:
                _locationGranted &&
                (_vehicleData.isEmpty ||
                    (_vehicleData['type'] as String? ?? '') == 'none' ||
                    (_vehicleData['type'] as String? ?? '').isEmpty),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
            onTap: (_) {
              setState(() => _selectedLotIndex = -1);
              _sheetController.animateTo(
                0.28,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
          ),

          // Top search
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _isSearching = true);
                      _sheetController.animateTo(
                        0.85,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 46,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          _isSearching
                              ? GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isSearching = false;
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                    _sheetController.animateTo(
                                      0.28,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  },
                                  child: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                )
                              : Icon(
                                  Icons.search_rounded,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _isSearching
                                ? TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      hintText: 'Search parking location...',
                                      border: InputBorder.none,
                                      filled: false,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: const TextStyle(fontSize: 14),
                                    onChanged: (value) {
                                      setState(() => _searchQuery = value);
                                    },
                                  )
                                : Text(
                                    'Search parking location...',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                          if (_isSearching && _searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setState(() => _searchQuery = '');
                                _searchController.clear();
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.grey[400],
                                  size: 18,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildChip('All', Icons.grid_view_rounded),
                      const SizedBox(width: 8),
                      _buildChip('EV Charging', Icons.electric_car_rounded),
                      const SizedBox(width: 8),
                      _buildChip('Available', Icons.local_parking_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Location button — hides when sheet is too high
          AnimatedBuilder(
            animation: _sheetController,
            builder: (context, child) {
              final size = _sheetController.isAttached
                  ? _sheetController.size
                  : 0.28;
              if (size > 0.6) return const SizedBox.shrink();
              return Positioned(
                right: 16,
                bottom: MediaQuery.of(context).size.height * size + 12,
                child: GestureDetector(
                  onTap: () {
                    if (_locationGranted) {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLng(_currentPosition),
                      );
                    } else {
                      _requestLocation();
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.my_location_rounded,
                      color: _locationGranted ? AppColors.primary : Colors.grey,
                      size: 20,
                    ),
                  ),
                ),
              );
            },
          ),

          // Draggable bottom sheet
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.35,
            minChildSize: 0.035,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.035, 0.28, 0.55, 0.85],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Collapsible header
                    AnimatedBuilder(
                      animation: _sheetController,
                      builder: (context, _) {
                        final size = _sheetController.isAttached
                            ? _sheetController.size
                            : 0.28;
                        if (size <= 0.05 || _selectedLotIndex >= 0) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Nearby parking',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Live',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  _buildStatCard(
                                    '$_totalAvailable',
                                    'Available',
                                    AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatCard(
                                    '$_fillingUp',
                                    'Filling up',
                                    AppColors.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatCard(
                                    '$_fullCount',
                                    'Full',
                                    AppColors.error,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Divider(height: 1, color: Colors.grey[200]),
                          ],
                        );
                      },
                    ),
                    // Content
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_selectedLotIndex >= 0)
                      _buildLotDetail(_parkingLots[_selectedLotIndex])
                    else
                      _buildParkingList(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    final isActive = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkingList() {
    final lots = _searchedLots;
    if (lots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No results for "$_searchQuery"'
                    : 'No $_selectedFilter lots found.',
                style: TextStyle(color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        ...lots.map((lot) => _buildNearbyItem(lot)),
        const SizedBox(height: 16),
      ],
    );
  }


  Widget _buildStatCard(String number, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              number,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyItem(ParkingLot lot) {
    final statusColor = _getStatusColor(lot.available, lot.total);

    return InkWell(
      onTap: () {
        final index = _parkingLots.indexOf(lot);
        setState(() => _selectedLotIndex = index);
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(lot.position),
        );
        _sheetController.animateTo(
          0.55,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: lot.isEv ? AppColors.evSurface : AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                lot.isEv ? Icons.electric_car_rounded : Icons.local_parking_rounded,
                color: lot.isEv ? AppColors.ev : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lot.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    lot.rate,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            lot.id == _activeSessionLotId
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_car_rounded,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Parked',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(lot.available),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildLotDetail(ParkingLot lot) {
    final occupancy = (lot.occupancyRatio * 100).round();
    final statusColor = _getStatusColor(lot.available, lot.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedLotIndex = -1);
              _sheetController.animateTo(
                0.28,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios_rounded,
                  size: 14,
                  color: Colors.grey[600],
                ),
                Text(
                  'Back to list',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Show active session banner if user is parked here
        if (lot.id == _activeSessionLotId) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withValues(alpha:0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_car_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'You are currently parked here',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActiveSessionScreen(parkingLot: lot),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: lot.isEv ? AppColors.ev : AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                lot.isEv ? Icons.electric_car_rounded : Icons.local_parking_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lot.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      lot.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha:0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                lot.rate,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildStatCard('${lot.available}', 'Available', AppColors.primary),
              const SizedBox(width: 8),
              _buildStatCard(
                '${lot.total - lot.available}',
                'Occupied',
                AppColors.error,
              ),
              const SizedBox(width: 8),
              _buildStatCard('${lot.total}', 'Total', Colors.grey),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Occupancy',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  Text(
                    '$occupancy%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: lot.occupancyRatio,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: lot.isEv ? AppColors.ev : AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: lot.available == 0
                ? null
                : () async {
                    // Check if already have active session
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      final existing = await FirebaseFirestore.instance
                          .collection('sessions')
                          .where('userId', isEqualTo: user.uid)
                          .where('status', isEqualTo: 'active')
                          .get();

                      if (existing.docs.isNotEmpty) {
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: const BoxDecoration(
                                      color: AppColors.warningSurface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: AppColors.warning,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Active Session Exists',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'You already have an active parking session. Please end it before starting a new one.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => Navigator.pop(context),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'OK',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.pop(context);
                                            homeScreenKey.currentState
                                                ?.switchTab(1);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'View Session',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActiveSessionScreen(parkingLot: lot),
                      ),
                    );
                  },
            child: Text(
              lot.available == 0
                  ? 'Parking Full'
                  : lot.isEv
                  ? 'Start EV Charging'
                  : 'Start Parking Session',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
