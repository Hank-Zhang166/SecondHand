/// 用户资料（profiles 表）
class UserProfile {
  final String ownerId;
  final String ownerName;
  final String nickname;
  final String avatarPath;
  final String studentId;
  final String department;
  final bool thuEmailVerified;

  UserProfile({
    required this.ownerId,
    required this.ownerName,
    required this.nickname,
    required this.avatarPath,
    required this.studentId,
    required this.department,
    required this.thuEmailVerified,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        ownerId: '${j['owner_id'] ?? ''}',
        ownerName: '${j['owner_name'] ?? ''}',
        nickname: ('${j['nickname'] ?? ''}').trim().isEmpty
            ? '清华同学'
            : '${j['nickname']}',
        avatarPath: '${j['avatar_path'] ?? ''}',
        studentId: '${j['student_id'] ?? ''}',
        department: '${j['department'] ?? ''}',
        thuEmailVerified: j['thu_email_verified'] == true,
      );

  /// 展示名：昵称优先
  String get displayName =>
      nickname.trim().isNotEmpty ? nickname : '清华同学';
}
