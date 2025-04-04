
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class OpenStreetMapScreen extends StatefulWidget {
  @override
  _OpenStreetMapScreenState createState() => _OpenStreetMapScreenState();
}

class _OpenStreetMapScreenState extends State<OpenStreetMapScreen> {
  final  fromControl = TextEditingController();
  final  toControl = TextEditingController();

  LatLng? fromLocation;
  LatLng? toLocation;
  double? distance;
  List<LatLng> routePoints = [];

  final  _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(20.5937, 78.9629),
                initialZoom: 5,
                onTap: (tapPosition, latLng) {
                  print("Map tapped at: $latLng");
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c'],
                ),
                if (routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 4.0,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                if (fromLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: fromLocation!,
                        width: 80,
                        height: 80,
                        child: Icon(Icons.location_pin, color: Colors.blue, size: 40),
                      ),
                    ],
                  ),
                if (toLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: toLocation!,
                        width: 80,
                        height: 80,
                        child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (distance != null)
                    Text(
                      "Total Distance is: ${distance!.toStringAsFixed(2)} km",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  SizedBox(height: 10),
                  TextField(
                    controller: fromControl,
                    decoration: InputDecoration(
                      labelText: "From (Enter Place Name)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: toControl,
                    decoration: InputDecoration(
                      labelText: "To (Enter Place Name)",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _updateRoute();
                    },
                    child: Text("Show Route", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateRoute() async {
    String fromPlace = fromControl.text.trim();
    String toPlace = toControl.text.trim();

    if (fromPlace.isEmpty || toPlace.isEmpty) {
      _showError("Please enter both locations.");
      return;
    }

    _showLoadingDialog();

    try {
      LatLng? fromLatLng = await _getCoordinates(fromPlace);
      LatLng? toLatLng = await _getCoordinates(toPlace);

      if (fromLatLng == null || toLatLng == null) {
        Navigator.pop(context); 
        _showError("Could not find locations. Try again.");
        return;
      }

      List<LatLng> routePath = await _getRoutePath(fromLatLng, toLatLng);
      
      double calculatedDistance = _calculateRouteDistance(fromLatLng, toLatLng, routePath);

      setState(() {
        fromLocation = fromLatLng;
        toLocation = toLatLng;
        routePoints = routePath;
        distance = calculatedDistance;
        
        double centerLat = (fromLatLng.latitude + toLatLng.latitude) / 2;
        double centerLng = (fromLatLng.longitude + toLatLng.longitude) / 2;
        
        double zoomLevel = _calculateZoomLevel(calculatedDistance);
        
        _mapController.move(LatLng(centerLat, centerLng), zoomLevel);
      });

      Navigator.pop(context);
    } catch (e) {
      Navigator.pop(context);
      _showError("Error: ${e.toString()}");
    }
  }

  Future<LatLng?> _getCoordinates(String placeName) async {
    final url = "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(placeName)}&format=json&limit=1";
    final response = await http.get(
      Uri.parse(url),
      headers: {"User-Agent": "MyMapApp/1.0"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.isNotEmpty) {
        double lat = double.parse(data[0]["lat"]);
        double lon = double.parse(data[0]["lon"]);
        return LatLng(lat, lon);
      }
    }
    return null;
  }

  Future<List<LatLng>> _getRoutePath(LatLng from, LatLng to) async {
    try {
      
      final url = "https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=full&geometries=geojson";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'];
          List<LatLng> routePoints = [];
          

          for (var coord in coordinates) {
            routePoints.add(LatLng(coord[1], coord[0]));
          }
          
          return routePoints;
        }
      }
    } catch (e) {
      print("Error fetching route: $e");
    }
    
    return [from, to];
  }

  double _calculateRouteDistance(LatLng from, LatLng to, List<LatLng> routePoints) {
    try {
      final url = "https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}?overview=false";
      http.get(Uri.parse(url)).then((response) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['routes'] != null && data['routes'].isNotEmpty) {
            double distanceFromAPI = data['routes'][0]['distance'] / 1000;
            setState(() {
              distance = distanceFromAPI;
            });
            return distanceFromAPI;
          }
        }
      });
    } catch (e) {
      print("Error getting route distance from API: $e");
    }
    
    if (routePoints.length > 1) {
      return _calculatePathDistance(routePoints);
    }
    
    final distanceCalculator = Distance();
    return distanceCalculator.as(LengthUnit.Kilometer, from, to);
  }

  double _calculatePathDistance(List<LatLng> points) {
    if (points.isEmpty || points.length < 2) {
      return 0;
    }
    
    double totalDistance = 0;
    final distanceCalculator = Distance();
    
    for (int i = 0; i < points.length - 1; i++) {
      double segmentDistance = distanceCalculator.distance(
        points[i],
        points[i + 1]
      ) / 1000; 
      totalDistance += segmentDistance;
    }
    
    return totalDistance;
  }

  double _calculateZoomLevel(double distanceInKm) {
    if (distanceInKm > 1000) return 4.0;
    if (distanceInKm > 500) return 5.0;
    if (distanceInKm > 200) return 6.0;
    if (distanceInKm > 100) return 7.0;
    if (distanceInKm > 50) return 8.0;
    if (distanceInKm > 20) return 9.0;
    if (distanceInKm > 10) return 10.0;
    if (distanceInKm > 5) return 11.0;
    if (distanceInKm > 2) return 12.0;
    return 13.0;
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Finding route..."),
            ],
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
