import 'package:dio/dio.dart';

String apiErrorMessage(Object error, {String fallback = 'Xatolik yuz berdi'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        final msg = detail['message']?.toString();
        if (msg != null && msg.trim().isNotEmpty) {
          return msg.trim();
        }
      } else {
        final text = detail?.toString();
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
      final message = data['message']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    final msg = error.message?.trim();
    if (msg != null && msg.isNotEmpty) {
      return msg;
    }
  }
  return fallback;
}

String? apiErrorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        final code = detail['code']?.toString();
        if (code != null && code.trim().isNotEmpty) {
          return code.trim();
        }
      }
    }
  }
  return null;
}
