import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/places/place.dart';
import '../../features/places/places_provider.dart';
import '../../theme/app_spacing.dart';

class NaverMapDebugScreen extends ConsumerStatefulWidget {
  const NaverMapDebugScreen({super.key});

  @override
  ConsumerState<NaverMapDebugScreen> createState() =>
      _NaverMapDebugScreenState();
}

class _NaverMapDebugScreenState extends ConsumerState<NaverMapDebugScreen> {
  NaverMapController? _controller;
  String _lastSignature = '';
  bool _isRequestingLocation = false;
  NOverlayImage? _placeMarkerIcon;

  Future<void> _syncMarkers(List<Place> places) async {
    final controller = _controller;
    if (controller == null) return;

    final signature = places.map((p) => p.id).join('|');
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    await controller.clearOverlays(type: NOverlayType.marker);

    _placeMarkerIcon ??= await _buildPlaceMarkerIcon(context);

    final overlays = <NAddableOverlay>{};
    for (final p in places) {
      overlays.add(
        NMarker(
          id: p.id,
          position: NLatLng(p.lat, p.lng),
          icon: _placeMarkerIcon,
          anchor: NPoint.relativeCenter,
          // Design spec was measured on a 1080px-wide device (typically ~3.0 DPR -> 360dp).
          // Convert physical px -> logical px (dp) so it looks consistent across devices.
          size: const Size(49 / 3.0, 49 / 3.0),
          caption: NOverlayCaption(text: p.name),
        ),
      );
    }
    if (overlays.isNotEmpty) {
      await controller.addOverlayAll(overlays);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Place>>>(activePlacesProvider, (_, next) {
      final places = next.valueOrNull;
      if (places != null) {
        _syncMarkers(places);
      }
    });

    final placesAsync = ref.watch(activePlacesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('지도'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingHorizontal),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
          child: Stack(
            children: [
              NaverMap(
                options: const NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: NLatLng(35.1595, 129.0756),
                    zoom: 14,
                  ),
                  // We use an explicit consent flow before requesting location permission.
                  locationButtonEnable: false,
                ),
                onMapReady: (controller) async {
                  _controller = controller;

                  final places = placesAsync.valueOrNull;
                  if (places != null) {
                    await _syncMarkers(places);
                  }
                },
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: ElevatedButton.icon(
                  onPressed: _isRequestingLocation
                      ? null
                      : () => _handleMyLocationTap(context),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('현 위치'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.paddingMD,
                      vertical: AppSpacing.paddingSM,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleMyLocationTap(BuildContext context) async {
    setState(() => _isRequestingLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        await Geolocator.openLocationSettings();
      }

      var perm = await Geolocator.checkPermission();

      // Only show the consent dialog when permission isn't already granted.
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('위치 접근 동의'),
            content: const Text('현 위치를 알고 싶으면 동의해주세요.\n동의하십니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('동의'),
              ),
            ],
          ),
        );
        if (ok != true) return;
      }

      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('권한 필요'),
            content: const Text('위치 권한이 영구적으로 거부되었습니다.\n설정에서 권한을 허용해주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
              TextButton(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
                child: const Text('설정 열기'),
              ),
            ],
          ),
        );
        return;
      }

      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final controller = _controller;
      if (controller == null) return;

      await _setMyLocationOverlay(
        controller,
        NLatLng(pos.latitude, pos.longitude),
      );

      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(pos.latitude, pos.longitude),
          zoom: 15,
        ),
      );
    } catch (_) {
      // ignore: keep UX simple for now (errors show up in logs)
    } finally {
      if (mounted) setState(() => _isRequestingLocation = false);
    }
  }

  Future<void> _setMyLocationOverlay(
    NaverMapController controller,
    NLatLng position,
  ) async {
    final overlay = controller.getLocationOverlay();
    // Use the native accuracy circle as a small "red dot" to avoid
    // any custom image rendering issues.
    overlay.setIconAlpha(0);
    overlay.setSubIconAlpha(0);
    overlay.setAnchor(NPoint.relativeCenter);
    overlay.setCircleColor(Colors.red.shade600);
    overlay.setCircleRadius(6);
    overlay.setCircleOutlineColor(Colors.white);
    overlay.setCircleOutlineWidth(2);
    overlay.setIsVisible(true);
    overlay.setPosition(position);
  }

  Future<NOverlayImage> _buildPlaceMarkerIcon(BuildContext context) async {
    return NOverlayImage.fromWidget(
      context: context,
      // 49px/31px are physical pixels @ ~3.0 DPR.
      size: const Size(49 / 3.0, 49 / 3.0),
      widget: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring: 49px, 47% opacity (#10C4AE @ 0.47)
          Container(
            width: 49 / 3.0,
            height: 49 / 3.0,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x7810C4AE), // ~47% alpha
            ),
          ),
          // Inner dot: 31px, solid #10C4AE
          Container(
            width: 31 / 3.0,
            height: 31 / 3.0,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF10C4AE),
            ),
          ),
        ],
      ),
    );
  }
}
