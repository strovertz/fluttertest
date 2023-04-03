import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong/latlong.dart' as latlng;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/material.dart';
import 'package:novos/map_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agriscan',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MapScreen(),
    );
  }
}


class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Completer<GoogleMapController> _controller = Completer();
  final LatLng _initialPosition = const LatLng(-28.899666, -54.555794);
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  Set<Polyline> _polylines = {};

  // Para desenhar polilinhas
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();

  // Para desenhar polígonos
  List<LatLng> polygonCoordinates = [];
  bool _drawingPolygon = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dataDir = await getApplicationDocumentsDirectory();
    final dataFile = File('${dataDir.path}/data.json');

    if (await dataFile.exists()) {
      final data = jsonDecode(await dataFile.readAsString()) as List<dynamic>;

      for (var item in data) {
        final type = item['type'] as String;
        final coords = (item['coords'] as List<dynamic>)
            .cast<List<double>>()
            .map((pair) => LatLng(pair[0], pair[1]))
            .toList();

        if (type == 'marker') {
          setState(() {
            _markers.add(Marker(
              markerId: MarkerId(item['id'] as String),
              position: coords[0],
              infoWindow: InfoWindow(title: item['title'] as String),
            ));
          });
        } else if (type == 'polygon') {
          setState(() {
            _polygons.add(Polygon(
              polygonId: PolygonId(item['id'] as String),
              points: coords,
              strokeColor: Colors.red,
              fillColor: _getFillColor(item['plantingDate'] as String),
              strokeWidth: 2,
            ));
          });
        }
      }
    }
  }

  Future<void> _saveData() async {
    final dataDir = await getApplicationDocumentsDirectory();
    final dataFile = File('${dataDir.path}/data.json');

    final data = <Map<String, dynamic>>[];

    for (final marker in _markers) {
      data.add({
        'type': 'marker',
        'id': marker.markerId.value,
        'coords': [marker.position.latitude, marker.position.longitude],
        'title': marker.infoWindow.title,
      });
    }

    for (final polygon in _polygons) {
      data.add({
        'type': 'polygon',
        'id': polygon.polygonId.value,
        'coords': polygon.points.map((point) =>
        [
          point.latitude,
          point.longitude
        ]).toList(),
        'plantingDate': DateTime.now().toIso8601String(),
      });
    }

    await dataFile.writeAsString(jsonEncode(data));
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  Future<void> _goToUserLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 16.0,
        ),
      ),
    );
  }

  Color _getFillColor(String plantingDateString) {
    final plantingDate = DateTime.parse(plantingDateString);
    final daysSincePlanting = DateTime
        .now()
        .difference(plantingDate)
        .inDays;

    if (daysSincePlanting <= 60) {
      return Colors.green;
    } else if (daysSincePlanting <= 90) {
      return Colors.yellow;
    } else if (daysSincePlanting <= 120) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Agriscan')),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
                target: _initialPosition, zoom: 13.0),
            markers: _markers,
            polygons: _polygons,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onTap: (point) {
              if (_drawingPolygon) {
                setState(() {
                  polygonCoordinates.add(point);
                });
              }
            },
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: FloatingActionButton(
                onPressed: _goToUserLocation,
                tooltip: 'Minha localização',
                child: Icon(Icons.my_location),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildSpeedDial(),
    );
  }

  SpeedDial _buildSpeedDial() {
    return SpeedDial(
      animatedIcon: AnimatedIcons.menu_close,
      children: [
        SpeedDialChild(
          child: Icon(Icons.add_location),
          label: 'Adicionar marcador',
          onTap: () async {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );

            final newMarker = Marker(
              markerId: MarkerId('${DateTime
                  .now()
                  .millisecondsSinceEpoch}'),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: InfoWindow(title: 'Marcador'),
            );

            setState(() {
              _markers.add(newMarker);
            });

            _saveData();
          },
        ),
        SpeedDialChild(
          child: Icon(Icons.edit),
          label: 'Desenhar polígono',
          onTap: () {
            setState(() {
              _drawingPolygon = !_drawingPolygon;

              if (!_drawingPolygon) {
                if (polygonCoordinates.isNotEmpty) {
                  final newPolygon = Polygon(
                    polygonId: PolygonId('${DateTime
                        .now()
                        .millisecondsSinceEpoch}'),
                    points: polygonCoordinates,
                    strokeColor: Colors.red,
                    fillColor: Colors.green.withOpacity(0.2),
                    strokeWidth: 2,
                  );

                  setState(() {
                    _polygons.add(newPolygon);
                  });

                  polygonCoordinates.clear();
                  _saveData();
                }
              }
            });
          },
        ),
      ],
    );
  }
}
