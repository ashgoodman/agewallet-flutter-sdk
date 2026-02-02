import 'types.dart';
import 'agewallet_core.dart';

export 'types.dart';

/// AgeWallet SDK for Flutter applications.
///
/// Provides age verification via OIDC/PKCE flow.
///
/// Example:
/// ```dart
/// final ageWallet = AgeWallet(
///   clientId: 'your-client-id',
///   redirectUri: 'https://yourapp.com/callback',
/// );
///
/// if (!await ageWallet.isVerified()) {
///   await ageWallet.startVerification();
/// }
/// ```
class AgeWallet {
  final AgeWalletCore _core;

  /// Create a new AgeWallet instance.
  ///
  /// [clientId] - Your client ID from the AgeWallet dashboard.
  /// [redirectUri] - Your app's universal link callback URL.
  /// [endpoints] - Optional custom endpoint configuration.
  AgeWallet({
    required String clientId,
    required String redirectUri,
    AgeWalletEndpoints? endpoints,
  }) : _core = AgeWalletCore(
          config: AgeWalletConfig(
            clientId: clientId,
            redirectUri: redirectUri,
            endpoints: endpoints,
          ),
        );

  /// Check if the user is currently verified.
  ///
  /// Returns `true` if verified and not expired, `false` otherwise.
  Future<bool> isVerified() => _core.isVerified();

  /// Start the verification flow.
  ///
  /// Opens the system browser to the AgeWallet authorization page.
  /// The callback is handled automatically when control returns to your app.
  Future<void> startVerification() => _core.startVerification();

  /// Manually handle a callback URL.
  ///
  /// Usually not needed as [startVerification] handles callbacks automatically.
  /// Use this if you're handling deep links manually.
  ///
  /// Returns `true` if verification succeeded, `false` otherwise.
  Future<bool> handleCallback(String url) => _core.handleCallback(url);

  /// Clear the stored verification state (logout).
  Future<void> clearVerification() => _core.clearVerification();
}
