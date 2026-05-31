enum AgencyMemberStatus {
  pending('pending'),
  active('active'),
  removed('removed');

  const AgencyMemberStatus(this.wireValue);
  final String wireValue;
  bool get isActive => this == AgencyMemberStatus.active;
  static AgencyMemberStatus fromWire(String v) =>
      AgencyMemberStatus.values.firstWhere((e) => e.wireValue == v);
}
