import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  // --- INTERSTITIAL ADS ---
  static InterstitialAd? _interstitialAd;
  static bool _isInterAdLoading = false;
  static int _interRetryAttempt = 0;

  // --- REWARDED ADS ---
  static RewardedAd? _rewardedAd;
  static bool _isRewardAdLoading = false;
  static int _rewardRetryAttempt = 0;
  
  // Prevent multiple initializations
  static bool _initialLoadTriggered = false;

  // TEST IDs (Replace with Real IDs for Production)
  static final String _interstitialAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-2572570007063815/2326651489' // Android Test ID
      : 'ca-app-pub-3940256099942544/4411468910'; // iOS Test ID

  static final String _rewardedAdUnitId = Platform.isAndroid
      ? 'ca-app-pub-2572570007063815/3276771078' // Android Test ID
      : 'ca-app-pub-3940256099942544/1712485313'; // iOS Test ID

  /// Loads both Interstitial and Rewarded Ads with staggering
  static void loadAds() {
    if (_initialLoadTriggered) return;
    _initialLoadTriggered = true;

    // 1. SAFETY DELAY: Wait 3 seconds to ensure Flutter engine & WebView are stable
    // This solves the "Unable to obtain a JavascriptEngine" error.
    Future.delayed(const Duration(seconds: 3), () {
      loadInterstitialAd();
      
      // 2. STAGGERED LOAD: Wait another 2 seconds before loading Rewarded Ad
      // This prevents choking the main thread with multiple ad requests
      Future.delayed(const Duration(seconds: 2), () {
        loadRewardedAd();
      });
    });
  }

  // ==========================
  // INTERSTITIAL AD LOGIC
  // ==========================

  static void loadInterstitialAd() {
    if (_interstitialAd != null || _isInterAdLoading) return;
    
    _isInterAdLoading = true;
    debugPrint("🔄 Loading Interstitial Ad...");

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('✅ Interstitial Ad loaded successfully.');
          _interstitialAd = ad;
          _isInterAdLoading = false;
          _interRetryAttempt = 0;
          _setInterAdCallbacks(ad);
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ Interstitial Ad failed to load: ${error.message}');
          _interstitialAd = null;
          _isInterAdLoading = false;
          _retryLoadInter();
        },
      ),
    );
  }

  static void _retryLoadInter() {
    _interRetryAttempt++;
    // Increased max retries to catch slow initializations
    if (_interRetryAttempt > 5) return; 
    // Progressive backoff: 2s, 4s, 6s...
    Future.delayed(Duration(seconds: 2 * _interRetryAttempt), loadInterstitialAd);
  }

  static void _setInterAdCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        debugPrint('👋 Interstitial Ad dismissed.');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Reload immediately
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint('❌ Interstitial Ad failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
      },
    );
  }

  static bool showInterstitialAd() {
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      return true;
    } else {
      debugPrint('⚠️ Interstitial Ad not ready. Reloading...');
      loadInterstitialAd();
      return false;
    }
  }

  // ==========================
  // REWARDED AD LOGIC
  // ==========================

  static void loadRewardedAd() {
    if (_rewardedAd != null || _isRewardAdLoading) return;

    _isRewardAdLoading = true;
    debugPrint("🔄 Loading Rewarded Ad...");

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          debugPrint('✅ Rewarded Ad loaded successfully.');
          _rewardedAd = ad;
          _isRewardAdLoading = false;
          _rewardRetryAttempt = 0;
          // We don't set callbacks here anymore, we set them on show()
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('❌ Rewarded Ad failed to load: ${error.message}');
          _rewardedAd = null;
          _isRewardAdLoading = false;
          _retryLoadReward();
        },
      ),
    );
  }

  static void _retryLoadReward() {
    _rewardRetryAttempt++;
    if (_rewardRetryAttempt > 5) return;
    Future.delayed(Duration(seconds: 2 * _rewardRetryAttempt), loadRewardedAd);
  }

  /// Shows Rewarded Ad. Triggers [onReward] if user finishes video, [onFailure] otherwise.
  static void showRewardedAd({required VoidCallback onReward, required VoidCallback onFailure}) {
    if (_rewardedAd != null) {
      bool isRewardEarned = false;

      // Set callbacks dynamically to handle specific success/fail flow
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (RewardedAd ad) {
          debugPrint('🎬 Rewarded Ad showing.');
        },
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          debugPrint('👋 Rewarded Ad dismissed.');
          ad.dispose();
          _rewardedAd = null;
          
          // If the user closed the ad without earning the reward, trigger failure
          if (!isRewardEarned) {
            debugPrint('⚠️ Ad closed without reward.');
            onFailure();
          }
          
          loadRewardedAd(); // Reload for next time
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          debugPrint('❌ Rewarded Ad failed to show: $error');
          ad.dispose();
          _rewardedAd = null;
          onFailure();
          loadRewardedAd();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          debugPrint('🎉 User earned reward: ${reward.amount} ${reward.type}');
          isRewardEarned = true;
          onReward();
        }
      );
    } else {
      debugPrint('⚠️ Rewarded Ad not ready. Reloading...');
      loadRewardedAd();
      onFailure();
    }
  }
}

// --- BANNER AD WIDGET ---
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-2572570007063815/4257027864'
      : 'ca-app-pub-3940256099942544/2435281174';

  @override
  void initState() {
    super.initState();
    // FAILSAFE: Automatically trigger ALL Ad Loads when Banner initializes
    // This safe because loadAds has checks to only run once.
    AdManager.loadAds();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SAFE: This is called when context is fully available
    _loadAd();
  }

  Future<void> _loadAd() async {
    if (!mounted) return;
    
    // Check if we already have a loaded ad to prevent reloading on every dependency change
    if (_bannerAd != null) return; 

    // 2. ADDED DELAY: Small delay for Banner as well to ensure engine readiness
    // Banner loads first, giving it a small head start.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) return;

    BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _bannerAd = ad as BannerAd;
              _isLoaded = true;
            });
            debugPrint('✅ Banner Ad loaded: ${ad.responseInfo}');
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Banner failed: $err');
          ad.dispose();
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerAd != null && _isLoaded) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink();
  }
}