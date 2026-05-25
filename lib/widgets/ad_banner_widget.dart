import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/colors.dart';
import '../services/ad_service.dart';

class AdBannerWidget extends StatefulWidget {
  final AdSize adSize;

  const AdBannerWidget({
    super.key,
    this.adSize = AdSize.banner,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isAdFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // If running on Web, Mobile Ads are not supported. Collapse gracefully.
    if (kIsWeb) {
      setState(() {
        _isAdFailed = true;
      });
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdService.instance.bannerAdUnitId,
      size: widget.adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
            _isAdFailed = false;
          });
          debugPrint('🎯 AdMob Banner Ad successfully loaded.');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('⚠️ AdMob Banner Ad failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _isAdFailed = true;
            });
          }
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Collapse to empty space if Web platform or if loading has failed.
    if (kIsWeb || _isAdFailed) {
      return const SizedBox.shrink();
    }

    final double width = widget.adSize.width.toDouble();
    final double height = widget.adSize.height.toDouble();

    return Center(
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Placeholder shown during load state
            if (!_isAdLoaded)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.accentBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sponsored',
                    style: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

            // 2. Banner Ad view
            if (_isAdLoaded && _bannerAd != null)
              AdWidget(ad: _bannerAd!),

            // 3. Small badge label to identify as ad
            if (_isAdLoaded)
              Positioned(
                top: 2,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'Ad',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
