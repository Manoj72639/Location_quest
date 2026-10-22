import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/quest.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  Position? _position;
  Quest? _selectedQuest;
  bool _busy = false;
  String? _locationError;

  @override
  void initState() { super.initState(); _refreshLocation(); }

  Future<Position> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Please enable device location services.');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to validate a quest.');
    }
    final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
    if (p.accuracy > 100) throw Exception('GPS accuracy is too low. Try again outdoors.');
    if (mounted) setState(() { _position = p; _locationError = null; });
    return p;
  }

  Future<void> _refreshLocation() async {
    try { await _getPosition(); }
    catch (e) { if (mounted) setState(() => _locationError = e.toString().replaceFirst('Exception: ', '')); }
  }

  Future<void> _validateQuest(Quest quest) async {
    setState(() => _busy = true);
    try {
      final p = await _getPosition();
      final result = await _api.validateQuest(questId: quest.id, latitude: p.latitude,
        longitude: p.longitude, accuracy: p.accuracy);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Validation complete.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final questsQuery = FirebaseFirestore.instance.collection('quests').where('isActive', isEqualTo: true);
    final completionsQuery = userRef.collection('completions');
    return Scaffold(
      appBar: AppBar(title: const Text('Location Quest'), actions: [
        IconButton(onPressed: _refreshLocation, icon: const Icon(Icons.my_location), tooltip: 'Refresh GPS'),
        IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout), tooltip: 'Sign out'),
      ]),
      body: Column(children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(stream: userRef.snapshots(), builder: (context, snap) {
          final xp = snap.data?.data()?['totalXp'] ?? 0;
          return Card(margin: const EdgeInsets.fromLTRB(12, 12, 12, 6), child: ListTile(
            leading: const Icon(Icons.stars, color: Colors.amber, size: 32), title: const Text('Total XP'),
            trailing: Text('$xp XP', style: Theme.of(context).textTheme.titleLarge)));
        }),
        if (_locationError != null) Padding(padding: const EdgeInsets.all(8), child: Text(_locationError!, style: const TextStyle(color: Colors.red))),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: questsQuery.snapshots(), builder: (context, qs) {
          if (qs.hasError) return const Center(child: Text('Unable to load quests.'));
          if (!qs.hasData) return const Center(child: CircularProgressIndicator());
          final quests = <Quest>[];
          for (final doc in qs.data!.docs) { try { quests.add(Quest.fromMap(doc.id, doc.data())); } catch (_) {} }
          if (quests.isEmpty) return const Center(child: Text('No active quests found.'));
          final chosen = _selectedQuest ?? quests.first;
          final center = _position == null ? LatLng(chosen.latitude, chosen.longitude) : LatLng(_position!.latitude, _position!.longitude);
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(stream: completionsQuery.snapshots(), builder: (context, cs) {
            final completed = cs.data?.docs.map((d) => d.id).toSet() ?? <String>{};
            final markers = <Marker>{
              for (final q in quests) Marker(markerId: MarkerId(q.id), position: LatLng(q.latitude, q.longitude),
                infoWindow: InfoWindow(title: q.name, snippet: '${q.xpReward} XP'), onTap: () => setState(() => _selectedQuest = q)),
              if (_position != null) Marker(markerId: const MarkerId('user-location'), position: LatLng(_position!.latitude, _position!.longitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), infoWindow: const InfoWindow(title: 'Your location')),
            };
            return ListView(children: [
              SizedBox(height: 260, child: GoogleMap(initialCameraPosition: CameraPosition(target: center, zoom: 14), markers: markers, myLocationEnabled: false)),
              for (final q in quests) Card(child: ListTile(
                selected: _selectedQuest?.id == q.id,
                leading: Icon(completed.contains(q.id) ? Icons.check_circle : Icons.place, color: completed.contains(q.id) ? Colors.green : null),
                title: Text(q.name), subtitle: Text('${q.description}\n${completed.contains(q.id) ? 'Completed' : 'Available'}'), isThreeLine: true,
                trailing: Text('${q.xpReward} XP'), onTap: () => setState(() => _selectedQuest = q))),
              if (_selectedQuest != null) ...[
                Padding(padding: const EdgeInsets.all(12), child: Text('Selected: ${_selectedQuest!.name}', style: Theme.of(context).textTheme.titleMedium)),
                if (_position != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('Approximate distance: ${Geolocator.distanceBetween(_position!.latitude, _position!.longitude, _selectedQuest!.latitude, _selectedQuest!.longitude).round()} metres')),
                Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: _busy || completed.contains(_selectedQuest!.id) ? null : () => _validateQuest(_selectedQuest!),
                  icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle),
                  label: Text(completed.contains(_selectedQuest!.id) ? 'Quest Completed' : _busy ? 'Validating...' : 'Validate Quest')))),
              ],
            ]);
          });
        })),
      ]),
    );
  }
}
