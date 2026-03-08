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
    this.hasPassword,
    this.loading = false,
    this.error,
  });

  final String? token;
  final int? userId;
  final String? role;
  final String? phone;
  final Map<String, dynamic>? profile;
  final bool? hasPassword;
  final bool loading;
  final String? error;

  bool get isLoggedIn => token != null;

  AuthState copyWith({
    String? token,
    int? userId,
    String? role,
    String? phone,
    Map<String, dynamic>? profile,
    bool? hasPassword,
    bool? loading,
    String? error,
  }) {
    return AuthState(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      profile: profile ?? this.profile,
      hasPassword: hasPassword ?? this.hasPassword,
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

  Future<bool?> checkPhoneStatus(String phone) async {
    try {
      state = state.copyWith(loading: true, error: null, phone: phone);
      final res = await ref
          .read(apiClientProvider)
          .post(Endpoints.phoneStatus, data: {'phone': phone});
      final hasPassword = res.data['has_password'] == true;
      state = state.copyWith(
        loading: false,
        phone: phone,
        hasPassword: hasPassword,
        error: null,
      );
      return hasPassword;
    } on DioException catch (e) {
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ?? '')
          : '';
      final msg = e.message?.trim() ?? '';
      state = state.copyWith(
        loading: false,
        error: detail.isNotEmpty
            ? detail
            : (msg.isNotEmpty ? msg : 'Telefon tekshirishda xatolik'),
      );
      return null;
    }
  }

  Future<bool> requestOtp(String phone, {String reason = 'register'}) async {
    try {
      state = state.copyWith(loading: true, error: null, phone: phone);
      await ref.read(apiClientProvider).post(
            Endpoints.requestOtp,
            data: {'phone': phone, 'reason': reason},
          );
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

  Future<bool> completeOtpAndSetPassword(
    String otp,
    String password, {
    String reason = 'register',
  }) async {
    if (state.phone == null) {
      state = state.copyWith(error: 'Telefon raqam topilmadi');
      return false;
    }

    try {
      state = state.copyWith(loading: true, error: null);
      final res = await ref.read(apiClientProvider).post(
        Endpoints.completeOtp,
        data: {
          'phone': state.phone,
          'otp': otp,
          'password': password,
          'reason': reason,
        },
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
        hasPassword: true,
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
            ? detail
            : (msg.isNotEmpty ? msg : 'OTP yoki parol xato'),
      );
      return false;
    }
  }

  Future<bool> loginWithPassword(String phone, String password) async {
    try {
      state = state.copyWith(loading: true, error: null, phone: phone);
      final res = await ref.read(apiClientProvider).post(
        Endpoints.loginPassword,
        data: {'phone': phone, 'password': password},
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
        hasPassword: true,
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
            ? detail
            : (msg.isNotEmpty ? msg : 'Kirishda xatolik'),
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
