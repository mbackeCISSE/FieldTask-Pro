import 'intervention.dart';
import 'intervention_repository.dart';

class GetInterventions {
  const GetInterventions(this.repository);
  final InterventionRepository repository;
  Future<List<Intervention>> call(
      {WorkStatus? status, String query = '', String? technicianId}) async {
    final needle = query.trim().toLowerCase();
    final rows = (await repository.watchSnapshot())
        .where((x) =>
            (status == null || x.status == status) &&
            (technicianId == null || x.assignedTechnicianId == technicianId) &&
            (needle.isEmpty ||
                '${x.id} ${x.title} ${x.client} ${x.address} ${x.equipment} ${x.description}'
                    .toLowerCase()
                    .contains(needle)))
        .toList();
    rows.sort((a, b) => Intervention.priorities[a.priority]!
        .compareTo(Intervention.priorities[b.priority]!));
    return rows;
  }
}
