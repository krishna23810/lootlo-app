/// Generic API error response matching backend ErrorResponse interface.
class ApiErrorResponse {
  final int status;
  final String code;
  final String message;
  final Map<String, String>? fields;
  final bool retryable;

  const ApiErrorResponse({
    required this.status,
    required this.code,
    required this.message,
    this.fields,
    required this.retryable,
  });

  factory ApiErrorResponse.fromJson(Map<String, dynamic> json) {
    return ApiErrorResponse(
      status: json['status'] as int,
      code: json['code'] as String,
      message: json['message'] as String,
      fields: json['fields'] != null
          ? Map<String, String>.from(json['fields'] as Map)
          : null,
      retryable: json['retryable'] as bool? ?? false,
    );
  }
}
