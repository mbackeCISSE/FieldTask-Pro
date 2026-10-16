class InterventionAttachment {
  const InterventionAttachment({
    required this.id,
    required this.interventionId,
    required this.kind,
    required this.path,
    required this.syncState,
  });

  final String id;
  final String interventionId;
  final String kind;
  final String path;
  final String syncState;
}
