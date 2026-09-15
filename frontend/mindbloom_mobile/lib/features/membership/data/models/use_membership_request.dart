class UseMembershipRequest {
  final int appointmentId;

  UseMembershipRequest({required this.appointmentId});

  Map<String, dynamic> toJson() {
    return {'appointmentId': appointmentId};
  }
}
