/// Auth Response model — represents what the API returns on login/register.
///
/// WHY a separate model?
/// The API response JSON needs to be converted to a Dart object.
/// Having a typed model means:
/// - Autocomplete in IDE (response.accessToken, not response['accessToken'])
/// - Compile-time safety (typos caught immediately, not at runtime)
/// - Single source of truth for the response shape

class AuthResponse {
  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final UserData user;

  AuthResponse({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.user,
  });

  /// Factory constructor — creates an AuthResponse from JSON map.
  /// Called like: AuthResponse.fromJson(responseData)
  ///
  /// WHY factory?
  /// A factory constructor can return an existing instance or create a new one.
  /// Here it's just a convenient way to parse JSON into our typed object.
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      accessTokenExpiresAt: DateTime.parse(json['accessTokenExpiresAt'] as String),
      refreshToken: json['refreshToken'] as String,
      refreshTokenExpiresAt: DateTime.parse(json['refreshTokenExpiresAt'] as String),
      user: UserData.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class UserData {
  final String id;
  final String email;
  final String mobile;
  final String displayName;
  final DateTime createdAt;

  UserData({
    required this.id,
    required this.email,
    required this.mobile,
    required this.displayName,
    required this.createdAt,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] as String,
      email: json['email'] as String,
      mobile: json['mobile'] as String,
      displayName: json['displayName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
