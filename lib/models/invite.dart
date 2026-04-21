class InviteModel {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final int timeControl;

  InviteModel({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.timeControl,
  });

  factory InviteModel.fromJson(Map<String, dynamic> json) {
    return InviteModel(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      fromUsername: json['fromUsername'] as String,
      timeControl: (json['timeControl'] as num).toInt(),
    );
  }
}
