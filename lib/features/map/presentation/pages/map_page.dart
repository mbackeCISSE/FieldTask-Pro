import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../app/widgets/field_task_navigation_bar.dart';
import '../../../interventions/domain/intervention.dart';
import '../map_cubit.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final map = MapController();
  bool _tileErrorShown = false;
  late Future<List<Intervention>> items;

  @override
  void initState() {
    super.initState();
    items = context.read<MapCubit>().loadInterventions();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Carte des interventions')),
        body: BlocListener<MapCubit, MapState>(
          listener: (context, state) {
            final location = state.location;
            if (location != null)
              map.move(LatLng(location.latitude, location.longitude), 14);
            if (state.error != null)
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(state.error!)));
          },
          child: FutureBuilder<List<Intervention>>(
            future: items,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(
                    child: Text('Carte indisponible : ${snapshot.error}'));
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final rows = snapshot.data!
                  .where((item) =>
                      item.latitude.isFinite &&
                      item.longitude.isFinite &&
                      item.latitude >= -90 &&
                      item.latitude <= 90 &&
                      item.longitude >= -180 &&
                      item.longitude <= 180 &&
                      !(item.latitude == 0 && item.longitude == 0))
                  .toList();
              return Stack(children: [
                FlutterMap(
                  mapController: map,
                  options: const MapOptions(
                      initialCenter: LatLng(14.68, -17.45), initialZoom: 9),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'sn.techfix.fieldtaskpro',
                      errorTileCallback: (_, __, ___) {
                        if (mounted && !_tileErrorShown) {
                          _tileErrorShown = true;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Fond de carte indisponible hors ligne. Les fiches restent accessibles.')));
                        }
                      },
                    ),
                    MarkerLayer(markers: [
                      ...rows.map((item) => Marker(
                            point: LatLng(item.latitude, item.longitude),
                            width: 48,
                            height: 48,
                            child: IconButton(
                                tooltip: item.title,
                                onPressed: () => quickView(item),
                                icon: Icon(Icons.location_on,
                                    color: item.priority == WorkPriority.urgent
                                        ? Colors.red
                                        : const Color(0xFF0D9488),
                                    size: 38)),
                          )),
                      if (context.watch<MapCubit>().state.location != null)
                        Marker(
                            point: LatLng(
                                context
                                    .watch<MapCubit>()
                                    .state
                                    .location!
                                    .latitude,
                                context
                                    .watch<MapCubit>()
                                    .state
                                    .location!
                                    .longitude),
                            width: 44,
                            height: 44,
                            child: const Icon(Icons.my_location,
                                color: Colors.blue, size: 32)),
                    ]),
                    RichAttributionWidget(attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors')
                    ]),
                  ],
                ),
                if (rows.isEmpty)
                  const Align(
                      alignment: Alignment.topCenter,
                      child: Card(
                          child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                  'Aucune intervention avec des coordonnées valides.')))),
              ]);
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.read<MapCubit>().locate(),
            icon: context.watch<MapCubit>().state.loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label: const Text('Ma position')),
        bottomNavigationBar: buildNavigationBar(context, 1),
      );

  void quickView(Intervention item) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                  Text('${item.client} · ${item.address}'),
                  const SizedBox(height: 10),
                  FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        context.push('/intervention/${item.id}');
                      },
                      child: const Text('Ouvrir la fiche complète')),
                ]),
          ));
}
