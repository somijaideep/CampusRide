import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LocationAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;

  const LocationAutocompleteField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    this.prefixIcon = Icons.location_on,
  });

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends State<LocationAutocompleteField> {
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;

  List<_PlaceSuggestion> _suggestions = [];

  bool _isLoading = false;
  bool _showSuggestions = false;

  int _requestId = 0;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && mounted) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;

        setState(() {
          _showSuggestions = false;
        });
      });
    } else if (_focusNode.hasFocus && mounted) {
      if (widget.controller.text.trim().length >= 2) {
        setState(() {
          _showSuggestions = true;
        });
      }
    }
  }

  void _onTextChanged() {
    final String query = widget.controller.text.trim();

    _debounce?.cancel();

    if (query.length < 2) {
      _requestId++;

      if (!mounted) return;

      setState(() {
        _suggestions = [];
        _isLoading = false;
        _showSuggestions = false;
      });

      return;
    }

    if (mounted) {
      setState(() {
        _showSuggestions = true;
      });
    }

    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _searchPlaces(query),
    );
  }

  Future<void> _searchPlaces(String query) async {
    final int requestId = ++_requestId;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });

    try {
      final Uri uri = Uri.https(
        'photon.komoot.io',
        '/api/',
        <String, String>{
          'q': query,
          'limit': '6',
          'lang': 'en',
          'lat': '16.4948',
          'lon': '80.4986',
        },
      );

      debugPrint('CampusRide location request: $uri');

      final http.Response response = await http
          .get(
            uri,
            headers: const <String, String>{
              'Accept': 'application/json',
              'User-Agent':
                  'CampusRide/1.0 (student ride-sharing project)',
            },
          )
          .timeout(const Duration(seconds: 20));

      debugPrint(
        'CampusRide Photon HTTP status: ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Photon returned HTTP ${response.statusCode}',
        );
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Unexpected location response format.',
        );
      }

      final dynamic rawFeatures = decoded['features'];

      if (rawFeatures is! List) {
        throw const FormatException(
          'Location response does not contain a features list.',
        );
      }

      final List<_PlaceSuggestion> places = [];

      for (final dynamic item in rawFeatures) {
        if (item is! Map<String, dynamic>) continue;

        final dynamic rawProperties = item['properties'];
        final dynamic rawGeometry = item['geometry'];

        if (rawProperties is! Map<String, dynamic>) continue;
        if (rawGeometry is! Map<String, dynamic>) continue;

        final dynamic rawCoordinates = rawGeometry['coordinates'];

        if (rawCoordinates is! List ||
            rawCoordinates.length < 2) {
          continue;
        }

        final dynamic rawLongitude = rawCoordinates[0];
        final dynamic rawLatitude = rawCoordinates[1];

        if (rawLongitude is! num || rawLatitude is! num) {
          continue;
        }

        final String address = _formatPlaceAddress(rawProperties);

        if (address.isEmpty) continue;

        final String name =
            (rawProperties['name'] ??
                    rawProperties['street'] ??
                    address)
                .toString();

        places.add(
          _PlaceSuggestion(
            name: name,
            address: address,
            latitude: rawLatitude.toDouble(),
            longitude: rawLongitude.toDouble(),
          ),
        );
      }

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _suggestions = places;
        _isLoading = false;
        _showSuggestions = true;
      });

      debugPrint('CampusRide locations found: ${places.length}');
    } on TimeoutException catch (error) {
      debugPrint('CampusRide location timeout: $error');

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _suggestions = [];
        _isLoading = false;
        _showSuggestions = true;
      });
    } on FormatException catch (error) {
      debugPrint('CampusRide location response error: $error');

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _suggestions = [];
        _isLoading = false;
        _showSuggestions = true;
      });
    } catch (error, stackTrace) {
      debugPrint('CampusRide location search error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _suggestions = [];
        _isLoading = false;
        _showSuggestions = true;
      });
    }
  }

  String _formatPlaceAddress(Map<String, dynamic> properties) {
    final List<String> parts = [];

    void addPart(dynamic value) {
      if (value == null) return;

      final String text = value.toString().trim();

      if (text.isNotEmpty && !parts.contains(text)) {
        parts.add(text);
      }
    }

    addPart(properties['name']);

    final String houseNumber =
        properties['housenumber']?.toString() ?? '';

    final String street =
        properties['street']?.toString() ?? '';

    if (houseNumber.isNotEmpty && street.isNotEmpty) {
      addPart('$houseNumber $street');
    } else {
      addPart(street);
    }

    addPart(properties['locality']);
    addPart(properties['district']);

    addPart(
      properties['city'] ??
          properties['town'] ??
          properties['village'] ??
          properties['county'],
    );

    addPart(properties['state']);
    addPart(properties['postcode']);
    addPart(properties['country']);

    return parts.join(', ');
  }

  void _selectPlace(_PlaceSuggestion place) {
    _debounce?.cancel();
    _requestId++;

    widget.controller.value = TextEditingValue(
      text: place.address,
      selection: TextSelection.collapsed(
        offset: place.address.length,
      ),
    );

    setState(() {
      _suggestions = [];
      _isLoading = false;
      _showSuggestions = false;
    });

    _focusNode.unfocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();

    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(widget.prefixIcon),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : widget.controller.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear location',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          widget.controller.clear();
                          _focusNode.requestFocus();
                        },
                      )
                    : const Icon(Icons.search),
          ),
        ),

        if (_showSuggestions && _suggestions.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(top: 4),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 240,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) {
                  final _PlaceSuggestion place =
                      _suggestions[index];

                  return ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF00897B),
                    ),
                    title: Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      place.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectPlace(place),
                  );
                },
              ),
            ),
          ),

        if (_showSuggestions &&
            !_isLoading &&
            _suggestions.isEmpty &&
            widget.controller.text.trim().length >= 2)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'No suggestions available. You can still enter a location manually.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),

        const Padding(
          padding: EdgeInsets.only(top: 5, left: 4),
          child: Text(
            'Location search powered by Photon / OpenStreetMap.',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceSuggestion {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const _PlaceSuggestion({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

