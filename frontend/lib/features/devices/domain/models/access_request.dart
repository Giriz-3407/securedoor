class AccessRequest {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String deviceId;
  final String deviceName;
  final String status; // 'pending' | 'accepted' | 'rejected'
  final DateTime requestedAt;

  const AccessRequest({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.deviceId,
    required this.deviceName,
    required this.status,
    required this.requestedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  factory AccessRequest.fromJson(Map<String, dynamic> json) {
    return AccessRequest(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userEmail: json['userEmail'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
