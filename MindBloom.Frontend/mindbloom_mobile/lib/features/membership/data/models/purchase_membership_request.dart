class PurchaseMembershipRequest {
  final int therapistId;
  final int planType;

  PurchaseMembershipRequest({
    required this.therapistId,
    required this.planType,
  });

  Map<String, dynamic> toJson() {
    return {'therapistId': therapistId, 'planType': planType};
  }
}
