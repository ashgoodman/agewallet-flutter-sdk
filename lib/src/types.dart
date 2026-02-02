/// Configuration and state types for AgeWallet SDK.

/// Custom endpoint configuration for AgeWallet SDK.
class AgeWalletEndpoints {
  final String? auth;
  final String? token;
  final String? userinfo;

  const AgeWalletEndpoints({
    this.auth,
    this.token,
    this.userinfo,
  });
}

/// Configuration for AgeWallet SDK.
class AgeWalletConfig {
  final String clientId;
  final String redirectUri;
  final AgeWalletEndpoints? endpoints;

  const AgeWalletConfig({
    required this.clientId,
    required this.redirectUri,
    this.endpoints,
  });

  String get authEndpoint =>
      endpoints?.auth ?? 'https://app.agewallet.io/user/authorize';

  String get tokenEndpoint =>
      endpoints?.token ?? 'https://app.agewallet.io/user/token';

  String get userinfoEndpoint =>
      endpoints?.userinfo ?? 'https://app.agewallet.io/user/userinfo';
}

/// Stored verification state.
class VerificationState {
  final String accessToken;
  final int expiresAt;
  final bool isVerified;

  const VerificationState({
    required this.accessToken,
    required this.expiresAt,
    required this.isVerified,
  });

  factory VerificationState.fromJson(Map<String, dynamic> json) {
    return VerificationState(
      accessToken: json['accessToken'] as String,
      expiresAt: json['expiresAt'] as int,
      isVerified: json['isVerified'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'expiresAt': expiresAt,
      'isVerified': isVerified,
    };
  }

  bool get isExpired => DateTime.now().millisecondsSinceEpoch >= expiresAt;
}

/// OIDC state stored during authorization flow.
class OidcState {
  final String state;
  final String verifier;
  final String nonce;

  const OidcState({
    required this.state,
    required this.verifier,
    required this.nonce,
  });

  factory OidcState.fromJson(Map<String, dynamic> json) {
    return OidcState(
      state: json['state'] as String,
      verifier: json['verifier'] as String,
      nonce: json['nonce'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'state': state,
      'verifier': verifier,
      'nonce': nonce,
    };
  }
}
