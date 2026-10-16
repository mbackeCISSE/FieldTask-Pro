import 'intervention.dart';
import 'intervention_attachment.dart';
import 'intervention_repository.dart';
import 'get_interventions.dart';

class InterventionUseCases {
  InterventionUseCases(InterventionRepository repository)
      : getSnapshot = GetInterventionSnapshot(repository),
        getInterventions = GetInterventions(repository),
        updateStatus = UpdateInterventionStatus(repository),
        addNote = AddInterventionNote(repository),
        saveAttachment = SaveInterventionAttachment(repository),
        getAttachments = GetInterventionAttachments(repository);

  final GetInterventionSnapshot getSnapshot;
  final GetInterventions getInterventions;
  final UpdateInterventionStatus updateStatus;
  final AddInterventionNote addNote;
  final SaveInterventionAttachment saveAttachment;
  final GetInterventionAttachments getAttachments;
}

/// Domain actions keep presentation independent from repository operations.
class GetInterventionSnapshot {
  const GetInterventionSnapshot(this.repository);
  final InterventionRepository repository;
  Future<List<Intervention>> call() => repository.watchSnapshot();
}

class UpdateInterventionStatus {
  const UpdateInterventionStatus(this.repository);
  final InterventionRepository repository;
  Future<void> call(String id, WorkStatus status) =>
      repository.updateStatus(id, status);
}

class AddInterventionNote {
  const AddInterventionNote(this.repository);
  final InterventionRepository repository;
  Future<void> call(String id, String note) => repository.addNote(id, note);
}

class SaveInterventionAttachment {
  const SaveInterventionAttachment(this.repository);
  final InterventionRepository repository;
  Future<void> call(String id, String kind, List<int> bytes,
          {required String extension}) =>
      repository.saveAttachment(id, kind, bytes, extension: extension);
}

class GetInterventionAttachments {
  const GetInterventionAttachments(this.repository);
  final InterventionRepository repository;
  Future<List<InterventionAttachment>> call(String id) =>
      repository.attachments(id);
}
