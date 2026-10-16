import 'intervention.dart';
import 'intervention_attachment.dart';

abstract interface class InterventionRepository {
  Future<List<Intervention>> watchSnapshot();
  Future<void> updateStatus(String id, WorkStatus status);
  Future<void> addNote(String id, String note);
  Future<void> saveAttachment(String id, String kind, List<int> bytes,
      {required String extension});
  Future<List<InterventionAttachment>> attachments(String id);
  Future<int> pendingOperations();
}
