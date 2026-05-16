import '../../domain/entities/user_search_result.dart';

class UserSearchResultDto {
  const UserSearchResultDto({
    required this.userId,
    required this.phone,
    required this.username,
    required this.fullName,
  });

  factory UserSearchResultDto.fromJson(Map<String, dynamic> json) {
    return UserSearchResultDto(
      userId: json['user_id'] as String,
      phone: json['phone'] as String?,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
    );
  }

  final String userId;
  final String? phone;
  final String? username;
  final String? fullName;

  UserSearchResult toEntity() {
    return UserSearchResult(
      userId: userId,
      phone: phone,
      username: username,
      fullName: fullName,
    );
  }
}
