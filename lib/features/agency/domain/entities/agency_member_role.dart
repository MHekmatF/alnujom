enum AgencyMemberRole {
  admin('admin'),
  agent('agent');

  const AgencyMemberRole(this.wireValue);
  final String wireValue;
  bool get isAdmin => this == AgencyMemberRole.admin;
  static AgencyMemberRole fromWire(String v) =>
      AgencyMemberRole.values.firstWhere((e) => e.wireValue == v);
}
