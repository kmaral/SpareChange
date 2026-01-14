import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static String get bannerAdUnitId {
    // Test Ad Unit ID - shows test ads
    return 'ca-app-pub-4704516790333123/3199849069';

    // When ready for production, replace with your real Banner Ad Unit ID:
    // return 'ca-app-pub-4704516790333123/YOUR_BANNER_AD_UNIT_ID';
  }

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('✅ Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Banner ad failed to load: $error');
          ad.dispose();
        },
        onAdOpened: (ad) {
          print('Banner ad opened');
        },
        onAdClosed: (ad) {
          print('Banner ad closed');
        },
      ),
    );
  }
}
