import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class AuthState {
  const AuthState({
    this.token,
    this.userId,
    this.role,
    this.phone,
    this.profile,
    this.loading = false,
    this.error,
  });

  final String? token;
  final int? userId;
  final String? role;
  final String? phone;
  final Map<String, dynamic>? profile;
  final bool loading;
  final String? error;

  bool get isLoggedIn => token != null;

  AuthState copyWith({
    String? token,
    int? userId,
    String? role,
    String? phone,
    Map<String, dynamic>? profile,
    bool? loading,
    String? error,
  }) {
    return AuthState(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      profile: profile ?? this.profile,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this.ref) : super(const AuthState());

  final Ref ref;

  Future<void> restore() async {
    final store = ref.read(secureStoreProvider);
    final token = await store.readToken();
    final role = await store.readRole();
    final userId = await store.readUserId();
    if (token != null) {
      state = state.copyWith(token: token, role: role, userId: userId);
      await loadProfile();
    }
  }

  Future<void> loadProfile() async {
    try {
      final res = await ref.read(apiClientProvider).get(Endpoints.myProfile);
      state =
          state.copyWith(profile: (res.data as Map).cast<String, dynamic>());
    } catch (_) {
      // silent for MVP
    }
  }

  Future<bool> requestOtp(String phone) async {
    try {
      state = state.copyWith(loading: true, error: null, phone: phone);
      await ref
          .read(apiClientProvider)
          .post(Endpoints.requestOtp, data: {'phone': phone});
      state = state.copyWith(loading: false, phone: phone, error: null);
      return true;
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ?? '')
          : '';
      final msg = e.message?.trim() ?? '';
      state = state.copyWith(
        loading: false,
        error: detail.isNotEmpty
            ? "OTP yuborishda xatolik: $detail"
            : (msg.isNotEmpty
                ? "OTP yuborishda xatolik: $msg"
                : 'OTP yuborishda xatolik'),
      );
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    if (state.phone == null) {
      state = state.copyWith(error: 'Telefon raqam topilmadi');
      return false;
    }
    try {
      state = state.copyWith(loading: true, error: null);
      final res = await ref.read(apiClientProvider).post(
        Endpoints.verifyOtp,
        data: {'phone': state.phone, 'otp': otp},
      );
      final token = res.data['access_token'] as String;
      final role = res.data['role'] as String;
      final userId = res.data['user']['id'] as int;
      final profile = (res.data['user'] as Map).cast<String, dynamic>();
      final store = ref.read(secureStoreProvider);
      await store.saveToken(token);
      await store.saveRole(role);
      await store.saveUserId(userId);
      state = state.copyWith(
        loading: false,
        token: token,
        role: role,
        userId: userId,
        profile: profile,
        error: null,
      );
      return true;
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ?? '')
          : '';
      final msg = e.message?.trim() ?? '';
      state = state.copyWith(
        loading: false,
        error: detail.isNotEmpty
            ? "OTP xatolik: $detail"
            : (msg.isNotEmpty ? "OTP xatolik: $msg" : 'OTP noto\'g\'ri'),
      );
      return false;
    }
  }

  Future<void> setRole(String role) async {
    final res = await ref
        .read(apiClientProvider)
        .post(Endpoints.setRole, data: {'role': role});
    final token = res.data['access_token'] as String;
    final store = ref.read(secureStoreProvider);
    await store.saveToken(token);
    await store.saveRole(role);
    state = state.copyWith(token: token, role: role);
    await loadProfile();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final res =
        await ref.read(apiClientProvider).put(Endpoints.myProfile, data: data);
    state = state.copyWith(profile: (res.data as Map).cast<String, dynamic>());
  }

  Future<void> logout() async {
    await ref.read(secureStoreProvider).clearAll();
    state = const AuthState();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
