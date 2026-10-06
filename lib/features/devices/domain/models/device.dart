enum DeviceConnectivity { online, offline }

enum DoorState { open, closed, unknown }

enum LatchState { locked, unlocked, transitioning, unknown }

class UserDevicePermission {
  final bool canOpen;
  final bool canClose;
  final bool isOwner;

  const UserDevicePermission({
    this.canOpen = true,
    this.canClose = true,
    this.isOwner = false,
  });

  factory UserDevicePermission.fromJson(Map<String, dynamic> json) {
    return UserDevicePermission(
      canOpen: json['canOpen'] as bool? ?? true,
      canClose: json['canClose'] as bool? ?? true,
      isOwner: json['isOwner'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'canOpen': canOpen,
    'canClose': canClose,
    'isOwner': isOwner,
  };
}

class Device {
  final String id;
  final String name;
  final String description;
  final DeviceConnectivity connectivity;
  final DoorState doorState;
  final LatchState latchState;
  final DateTime lastSeen;
  final UserDevicePermission permissions;
  final String? ipAddress;
  final String? hardwareFirmwareVersion;

  const Device({
    required this.id,
    required this.name,
    required this.description,
    required this.connectivity,
    required this.doorState,
    required this.latchState,
    required this.lastSeen,
    required this.permissions,
    this.ipAddress,
    this.hardwareFirmwareVersion,
  });

  bool get isOnline => connectivity == DeviceConnectivity.online;
  bool get isLocked => latchState == LatchState.locked;
  bool get isUnlocked => latchState == LatchState.unlocked;

  Device copyWith({
    String? id,
    String? name,
    String? description,
    DeviceConnectivity? connectivity,
    DoorState? doorState,
    LatchState? latchState,
    DateTime? lastSeen,
    UserDevicePermission? permissions,
    String? ipAddress,
    String? hardwareFirmwareVersion,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      connectivity: connectivity ?? this.connectivity,
      doorState: doorState ?? this.doorState,
      latchState: latchState ?? this.latchState,
      lastSeen: lastSeen ?? this.lastSeen,
      permissions: permissions ?? this.permissions,
      ipAddress: ipAddress ?? this.ipAddress,
      hardwareFirmwareVersion:
          hardwareFirmwareVersion ?? this.hardwareFirmwareVersion,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      connectivity: (json['connectivity'] == 'online')
          ? DeviceConnectivity.online
          : DeviceConnectivity.offline,
      doorState: switch (json['doorState']) {
        'open' => DoorState.open,
        'closed' => DoorState.closed,
        _ => DoorState.unknown,
      },
      latchState: switch (json['latchState']) {
        'locked' => LatchState.locked,
        'unlocked' => LatchState.unlocked,
        'transitioning' => LatchState.transitioning,
        _ => LatchState.unknown,
      },
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : DateTime.now(),
      permissions: json['permissions'] != null
          ? UserDevicePermission.fromJson(
              json['permissions'] as Map<String, dynamic>,
            )
          : const UserDevicePermission(),
      ipAddress: json['ipAddress'] as String?,
      hardwareFirmwareVersion: json['firmwareVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'connectivity': connectivity.name,
    'doorState': doorState.name,
    'latchState': latchState.name,
    'lastSeen': lastSeen.toIso8601String(),
    'permissions': permissions.toJson(),
    'ipAddress': ipAddress,
    'firmwareVersion': hardwareFirmwareVersion,
  };
}
