import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/ride_data.dart';
import '../models/ride_model.dart';
import 'find_ride_screen.dart';
import 'offer_ride_screen.dart';
import 'profile_screen.dart';
import 'ride_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color campusRideTeal = Color(0xFF00897B);
  static final LatLng campusLocation = LatLng(16.4948, 80.4986);

  final MapController mapController = MapController();

  StreamSubscription<List<Ride>>? _rideSubscription;

  LatLng? currentLocation;

  bool isGettingLocation = false;
  bool mapReady = false;
  bool isLoadingRides = true;

  List<Ride> availableRides = [];

  final Map<String, LatLng> _coordinateCache = {};
  final Map<String, LatLng> _rideCoordinates = {};
  final Map<String, Future<LatLng?>> _pendingGeocoding = {};

  @override
  void initState() {
    super.initState();
    _listenToRides();
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    mapController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // LIVE FIRESTORE RIDE UPDATES
  // --------------------------------------------------

  void _listenToRides() {
    _rideSubscription = RideData.watchRides().listen(
      (rides) {
        if (!mounted) return;

        final filteredRides = rides.where(_isAvailableRide).toList();

        setState(() {
          availableRides = filteredRides;
          isLoadingRides = false;
        });

        _resolveRideCoordinates(filteredRides);
      },
      onError: (Object error) {
        if (!mounted) return;

        setState(() {
          isLoadingRides = false;
        });

        _showMessage(
          'Unable to load rides. Check your internet connection.',
        );
      },
    );
  }

  bool _isAvailableRide(Ride ride) {
    if (ride.status != 'Active') return false;
    if (ride.availableSeats <= 0) return false;

    final departure = _getRideDateTime(ride);

    if (departure != null) {
      final waitingEnd = departure.add(
        const Duration(minutes: 10),
      );

      if (!DateTime.now().isBefore(waitingEnd)) {
        return false;
      }
    }

    return true;
  }

  DateTime? _getRideDateTime(Ride ride) {
    try {
      final dateParts = ride.date.split('/');

      if (dateParts.length != 3) return null;

      final day = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final year = int.parse(dateParts[2]);

      final timeParts = ride.time.trim().split(RegExp(r'\s+'));
      final clockParts = timeParts[0].split(':');

      int hour = int.parse(clockParts[0]);
      final minute = int.parse(clockParts[1]);

      if (timeParts.length > 1) {
        final period = timeParts[1].toUpperCase();

        if (period == 'PM' && hour != 12) {
          hour += 12;
        }

        if (period == 'AM' && hour == 12) {
          hour = 0;
        }
      }

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------
  // PICKUP ADDRESS GEOCODING
  // --------------------------------------------------

  Future<void> _resolveRideCoordinates(List<Ride> rides) async {
    final activeIds = rides.map((ride) => ride.id).toSet();

    _rideCoordinates.removeWhere(
      (rideId, _) => !activeIds.contains(rideId),
    );

    for (final ride in rides) {
      if (_rideCoordinates.containsKey(ride.id)) continue;

      final coordinate = await _geocodeAddress(ride.pickup);

      if (!mounted) return;

      if (coordinate != null) {
        _rideCoordinates[ride.id] = coordinate;

        setState(() {});
      }
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    final query = address.trim();

    if (query.isEmpty) return null;

    if (_coordinateCache.containsKey(query)) {
      return _coordinateCache[query];
    }

    if (_pendingGeocoding.containsKey(query)) {
      return _pendingGeocoding[query]!;
    }

    final future = _fetchCoordinates(query);
    _pendingGeocoding[query] = future;

    try {
      final result = await future;

      if (result != null) {
        _coordinateCache[query] = result;
      }

      return result;
    } finally {
      _pendingGeocoding.remove(query);
    }
  }

  Future<LatLng?> _fetchCoordinates(String address) async {
    try {
      final uri = Uri.https(
        'photon.komoot.io',
        '/api/',
        {
          'q': address,
          'limit': '1',
          'lat': campusLocation.latitude.toString(),
          'lon': campusLocation.longitude.toString(),
          'lang': 'en',
        },
      );

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'CampusRide/1.0 (student ride-sharing project)',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) return null;

      final features = decoded['features'];

      if (features is! List || features.isEmpty) return null;

      final feature = features.first;

      if (feature is! Map<String, dynamic>) return null;

      final geometry = feature['geometry'];

      if (geometry is! Map<String, dynamic>) return null;

      final coordinates = geometry['coordinates'];

      if (coordinates is! List || coordinates.length < 2) {
        return null;
      }

      final longitude = (coordinates[0] as num).toDouble();
      final latitude = (coordinates[1] as num).toDouble();

      if (latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        return null;
      }

      return LatLng(latitude, longitude);
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------
  // CURRENT LOCATION
  // --------------------------------------------------

  Future<void> _getCurrentLocation() async {
    if (isGettingLocation) return;

    setState(() {
      isGettingLocation = true;
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage('Please enable Location/GPS on your device.');
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage('Location permission was denied.');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Enable location permission in your app settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      setState(() {
        currentLocation = location;
      });

      if (mapReady) {
        mapController.move(location, 16);
      }

      _showMessage('Your current location is displayed.');
    } catch (_) {
      _showMessage('Unable to get your location. Try again.');
    } finally {
      if (mounted) {
        setState(() {
          isGettingLocation = false;
        });
      }
    }
  }

  // --------------------------------------------------
  // AVAILABLE RIDES LIST
  // --------------------------------------------------

  void _showAvailableRides() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Available Rides',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${availableRides.length} rides',
                        style: const TextStyle(
                          color: campusRideTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: isLoadingRides
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: campusRideTeal,
                          ),
                        )
                      : availableRides.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.directions_car_outlined,
                                      size: 56,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No available rides right now.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: availableRides.length,
                              itemBuilder: (context, index) {
                                final ride = availableRides[index];

                                return Card(
                                  margin: const EdgeInsets.only(
                                    bottom: 12,
                                  ),
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.all(12),
                                    leading: const CircleAvatar(
                                      backgroundColor: campusRideTeal,
                                      child: Icon(
                                        Icons.directions_car,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Text(
                                      '${ride.pickup} → ${ride.destination}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding:
                                          const EdgeInsets.only(top: 8),
                                      child: Text(
                                        '${ride.date} • ${ride.time}\n'
                                        'Seats: ${ride.availableSeats}\n'
                                        'Estimated cost per person: '
                                        '₹${ride.costPerPerson.toStringAsFixed(0)}',
                                      ),
                                    ),
                                    isThreeLine: true,
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      color: campusRideTeal,
                                    ),
                                    onTap: () {
                                      Navigator.pop(sheetContext);

                                      Navigator.push(
                                        this.context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              RideDetailsScreen(
                                            ride: ride,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // RIDE MARKER PREVIEW
  // --------------------------------------------------

  void _showRidePreview(Ride ride) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Available Ride',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _previewRow(
                  Icons.person_outline,
                  'Offered by',
                  ride.rideCreatorName,
                ),
                _previewRow(
                  Icons.trip_origin,
                  'Pickup',
                  ride.pickup,
                ),
                _previewRow(
                  Icons.flag_outlined,
                  'Destination',
                  ride.destination,
                ),
                _previewRow(
                  Icons.calendar_today_outlined,
                  'Date',
                  ride.date,
                ),
                _previewRow(
                  Icons.access_time,
                  'Departure',
                  ride.time,
                ),
                _previewRow(
                  Icons.event_seat_outlined,
                  'Available seats',
                  '${ride.availableSeats}',
                ),
                _previewRow(
                  Icons.currency_rupee,
                  'Cost per person',
                  '₹${ride.costPerPerson.toStringAsFixed(0)}',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: campusRideTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RideDetailsScreen(
                            ride: ride,
                          ),
                        ),
                      );
                    },
                    child: const Text('View Ride & Join'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _previewRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: campusRideTeal, size: 21),
          const SizedBox(width: 10),
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // --------------------------------------------------
  // HOME SCREEN
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      Marker(
        point: campusLocation,
        width: 150,
        height: 75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: campusRideTeal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'VIT-AP University',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const Icon(
              Icons.location_on,
              color: campusRideTeal,
              size: 34,
            ),
          ],
        ),
      ),
    ];

    for (final ride in availableRides) {
      final coordinate = _rideCoordinates[ride.id];

      if (coordinate == null) continue;

      markers.add(
        Marker(
          point: coordinate,
          width: 54,
          height: 62,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showRidePreview(ride),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: campusRideTeal,
                    size: 24,
                  ),
                ),
                const Icon(
                  Icons.location_on,
                  color: campusRideTeal,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (currentLocation != null) {
      markers.add(
        Marker(
          point: currentLocation!,
          width: 100,
          height: 70,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You are here',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 11,
                ),
              ),
              Icon(
                Icons.my_location,
                color: Colors.blue,
                size: 30,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CampusRide',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: campusRideTeal,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to CampusRide!',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connect with fellow students and make every '
                    'journey easier.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FindRideScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Find a Ride'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: campusRideTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OfferRideScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.directions_car),
                      label: const Text('Offer a Ride'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: campusRideTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person),
                      label: const Text('My Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: campusRideTeal,
                        side: const BorderSide(
                          color: campusRideTeal,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Available rides heading and View All button.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.map_outlined,
                    color: campusRideTeal,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Available Rides',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isLoadingRides)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Text(
                      '${availableRides.length}',
                      style: const TextStyle(
                        color: campusRideTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  TextButton(
                    onPressed: _showAvailableRides,
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: campusRideTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        isGettingLocation ? null : _getCurrentLocation,
                    tooltip: 'Show my current location',
                    color: campusRideTeal,
                    icon: isGettingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.my_location),
                  ),
                  TextButton(
                    onPressed: () {
                      if (mapReady) {
                        mapController.move(campusLocation, 15);
                      }
                    },
                    child: const Text('Campus'),
                  ),
                ],
              ),
            ),

            // Map and markers.
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: campusLocation,
                        initialZoom: 15,
                        minZoom: 4,
                        maxZoom: 18,
                        onMapReady: () {
                          mapReady = true;
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/'
                              '{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.example.campusride',
                        ),
                        MarkerLayer(markers: markers),
                        RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              'OpenStreetMap contributors',
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (!isLoadingRides && availableRides.isEmpty)
                      Positioned(
                        left: 12,
                        right: 64,
                        top: 12,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'No available rides right now.',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Column(
                        children: [
                          _MapControlButton(
                            icon: Icons.add,
                            tooltip: 'Zoom in',
                            onPressed: () {
                              final camera = mapController.camera;
                              mapController.move(
                                camera.center,
                                camera.zoom + 1,
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          _MapControlButton(
                            icon: Icons.remove,
                            tooltip: 'Zoom out',
                            onPressed: () {
                              final camera = mapController.camera;
                              mapController.move(
                                camera.center,
                                camera.zoom - 1,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon),
        color: const Color(0xFF00897B),
        constraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 42,
        ),
      ),
    );
  }
}
