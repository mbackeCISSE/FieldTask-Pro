class Technician {
  const Technician(
      {required this.name,
      required this.company,
      this.id = 'techfix-demo-1',
      this.role = 'Technicien',
      this.isLocalDemo = false});
  final String name;
  final String company;
  final String id;
  final String role;
  final bool isLocalDemo;
}
