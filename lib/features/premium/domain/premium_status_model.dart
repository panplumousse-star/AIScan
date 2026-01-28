import 'package:freezed_annotation/freezed_annotation.dart';

part 'premium_status_model.freezed.dart';
part 'premium_status_model.g.dart';

/// Represents the user's premium subscription status.
@freezed
class PremiumStatus with _$PremiumStatus {
  const factory PremiumStatus({
    /// Whether the user has an active premium subscription.
    @Default(false) bool isPremium,

    /// The date when the premium was purchased.
    DateTime? purchaseDate,

    /// The purchase token from Google Play for validation.
    String? purchaseToken,

    /// Whether the purchase has been validated with the store.
    @Default(false) bool isValidated,
  }) = _PremiumStatus;

  factory PremiumStatus.fromJson(Map<String, dynamic> json) =>
      _$PremiumStatusFromJson(json);
}
