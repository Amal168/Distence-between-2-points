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
  final  fromController = TextEditingController();
  final  toController = TextEditingController();

  LatLng? fromLocation;
  LatLng? toLocation;
  double? distance; 

  final  _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, 
      onPopInvoked: (didPop) {
        FocusScope.of(context)
            .unfocus(); 
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(" Distence Between 2 Pionts ")),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context)
                .unfocus();
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: fromController,
                        decoration: InputDecoration(
                          labelText: "From",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextField(
                        controller: toController,
                        decoration: InputDecoration(
                          labelText: "To",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(
                                 Colors.black26)),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _updateRoute();
                        },
                        child: Text(
                          "Show Distance",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 10),
                      if (distance != null)
                        Text(
                          "The Calculated Distance Is: ${distance!.toStringAsFixed(2)} km",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      onTap: (tapPosition, latLng) {
                        print("Map tapped at: $latLng");
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      if (fromLocation != null && toLocation != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [fromLocation!, toLocation!],
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
                              child: const Icon(Icons.location_pin,
                                  color: Colors.blue, size: 40),
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
                              child: const Icon(Icons.location_pin,
                                  color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _updateRoute() async {
    String fromPlace = fromController.text.trim();
    String toPlace = toController.text.trim();

    if (fromPlace.isEmpty || toPlace.isEmpty) {
      _showError("Please enter both locations.");
      return;
    }

    LatLng? fromLatLng = await _getCoordinates(fromPlace);
    LatLng? toLatLng = await _getCoordinates(toPlace);

    if (fromLatLng == null || toLatLng == null) {
      _showError("Could not find locations. Try again.");
      return;
    }

    final Distance distanceCalculator = Distance();
    double calculatedDistance =
        distanceCalculator.as(LengthUnit.Kilometer, fromLatLng, toLatLng);

    print("From: $fromLatLng, To: $toLatLng, Distance: $calculatedDistance km");

    setState(() {
      fromLocation = fromLatLng;
      toLocation = toLatLng;
      distance = calculatedDistance;
      _mapController.move(fromLocation!, 6.0);
    });
  }

  Future<LatLng?> _getCoordinates(String placeName) async {
    final url =
        "https://nominatim.openstreetmap.org/search?q=$placeName&format=json&limit=1";
    print("Fetching coordinates for: $placeName");

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
       print("Response Data: $data");

      if (data.isNotEmpty) {
        double lat = double.parse(data[0]["lat"]);
        double lon = double.parse(data[0]["lon"]);
        return LatLng(lat, lon);
      }
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
