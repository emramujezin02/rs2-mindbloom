class AddFavoriteRequest {
  final int therapistId;

  AddFavoriteRequest({required this.therapistId});

  Map<String, dynamic> toJson() {
    return {'therapistId': therapistId};
  }
}
