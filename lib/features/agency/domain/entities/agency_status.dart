enum AgencyStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  suspended('suspended');

  const AgencyStatus(this.wireValue);
  final String wireValue;

  bool get isPublic => this == AgencyStatus.approved;
  bool get canPublishUnder =>
      this == AgencyStatus.pending || this == AgencyStatus.approved;

  static AgencyStatus fromWire(String v) =>
      AgencyStatus.values.firstWhere((e) => e.wireValue == v);
}
