import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // Active AdMob App ID
  static const String appId = 'ca-app-pub-5536368658545776~2205071093';

  // Active Real Ad Unit ID (from user)
  static const String realBannerAdUnitIdAndroid = 'ca-app-pub-5536368658545776/3817912966';
  static const String realBannerAdUnitIdiOS = 'ca-app-pub-5536368658545776/3817912966'; // fallback

  // Official AdMob Test Banner Ad Unit IDs
  static const String testBannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const String testBannerAdUnitIdiOS = 'ca-app-pub-3940256099942544/2934735716';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the Google Mobile Ads SDK
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('ℹ️ Mobile Ads initialization skipped on Web platform.');
      return;
    }
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('✅ Google Mobile Ads SDK successfully initialized.');
    } catch (e) {
      debugPrint('⚠️ Error initializing Google Mobile Ads SDK: $e');
    }
  }

  /// Get the appropriate Banner Ad Unit ID based on the platform and build mode (Test vs Real)
  String get bannerAdUnitId {
    // In debug mode, ALWAYS use test ads to protect the user's account from suspension!
    if (kDebugMode) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return testBannerAdUnitIdAndroid;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return testBannerAdUnitIdiOS;
      }
      return testBannerAdUnitIdAndroid; // fallback
    }

    // In release/production mode, use the real production ad units!
    if (defaultTargetPlatform == TargetPlatform.android) {
      return realBannerAdUnitIdAndroid;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return realBannerAdUnitIdiOS;
    }
    return realBannerAdUnitIdAndroid; // fallback
  }
}
