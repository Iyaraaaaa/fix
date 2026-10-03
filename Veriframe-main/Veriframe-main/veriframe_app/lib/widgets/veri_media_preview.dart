import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:veriframe_app/models/verification_result.dart';

/// Universal, robust media preview component for VeriFrame.
///
/// Reliably extracts and renders images, videos, web links, and live streams as
/// visual previews across Media History and Forensic Report screens.
class VeriMediaPreview extends StatefulWidget {
  final VerificationResult report;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showPlayBadge;
  final bool showLiveBadge;
  final bool showDuration;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const VeriMediaPreview({
    super.key,
    required this.report,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showPlayBadge = true,
    this.showLiveBadge = true,
    this.showDuration = false,
    this.backgroundColor,
    this.onTap,
  });

  /// In-memory cache for extracted video thumbnails so scrolling list is butter smooth
  static final Map<String, Uint8List> _videoThumbnailCache = {};

  /// Extracts YouTube video ID from various YouTube URL formats.
  static String? extractYoutubeVideoId(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return null;
    final clean = rawUrl.trim();
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=|shorts\/)|youtu\.be\/)([^"&?\/ ]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(clean);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }

  /// Returns a YouTube thumbnail image URL if the given URL is a YouTube link.
  static String? getYoutubeThumbnailUrl(String? rawUrl) {
    final videoId = extractYoutubeVideoId(rawUrl);
    if (videoId != null) {
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    return null;
  }

  @override
  State<VeriMediaPreview> createState() => _VeriMediaPreviewState();
}

class _VeriMediaPreviewState extends State<VeriMediaPreview> {
  Uint8List? _asyncVideoThumb;
  bool _isLoadingAsyncThumb = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadAsyncVideoThumbnail();
  }

  @override
  void didUpdateWidget(covariant VeriMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.verificationId != widget.report.verificationId ||
        oldWidget.report.mediaPath != widget.report.mediaPath) {
      _checkAndLoadAsyncVideoThumbnail();
    }
  }

  void _checkAndLoadAsyncVideoThumbnail() {
    final r = widget.report;
    final hasBase64 = r.thumbnailBase64 != null && r.thumbnailBase64!.trim().isNotEmpty;
    if (hasBase64) return;

    final path = r.mediaPath;
    if (path == null || path.isEmpty || path.startsWith('http') || path.startsWith('stream-')) {
      return;
    }

    if (VeriMediaPreview._videoThumbnailCache.containsKey(path)) {
      _asyncVideoThumb = VeriMediaPreview._videoThumbnailCache[path];
      return;
    }

    final file = File(path);
    if (!file.existsSync()) return;

    final isImage = _isImageFile(path) || r.mediaType.toLowerCase().contains('image');
    if (isImage) return;

    _isLoadingAsyncThumb = true;
    vt.VideoThumbnail.thumbnailData(
      video: path,
      imageFormat: vt.ImageFormat.JPEG,
      maxWidth: 360,
      quality: 75,
    ).then((data) {
      if (data != null && mounted) {
        VeriMediaPreview._videoThumbnailCache[path] = data;
        setState(() {
          _asyncVideoThumb = data;
          _isLoadingAsyncThumb = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingAsyncThumb = false);
      }
    }).catchError((_) {
      if (mounted) setState(() => _isLoadingAsyncThumb = false);
    });
  }

  bool _isImageFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp');
  }

  bool _isAudioModality(VerificationResult r) {
    final mType = r.mediaType.toLowerCase();
    final source = r.source.toLowerCase();
    final name = (r.mediaName ?? '').toLowerCase();
    final path = (r.mediaPath ?? '').toLowerCase();
    final url = (r.videoUrl ?? '').toLowerCase();

    return mType.contains('audio') ||
        name.endsWith('.mp3') || name.endsWith('.wav') || name.endsWith('.m4a') || name.endsWith('.aac') ||
        path.endsWith('.mp3') || path.endsWith('.wav') || path.endsWith('.m4a') ||
        url.endsWith('.mp3') || url.endsWith('.wav') || url.endsWith('.m4a') ||
        source.contains('audio') || source.contains('voice');
  }

  bool _isImageModality(VerificationResult r) {
    final mType = r.mediaType.toLowerCase();
    final source = r.source.toLowerCase();
    final name = (r.mediaName ?? '').toLowerCase();
    final path = (r.mediaPath ?? '').toLowerCase();
    final url = (r.videoUrl ?? '').toLowerCase();

    return mType.contains('image') ||
        _isImageFile(name) ||
        _isImageFile(path) ||
        _isImageFile(url) ||
        source.contains('image');
  }

  bool _isLiveStreamModality(VerificationResult r) {
    final source = r.source.toLowerCase();
    final name = (r.mediaName ?? '').toLowerCase();
    final path = (r.mediaPath ?? '').toLowerCase();

    return source.contains('stream') ||
        source.contains('live') ||
        name.contains('live stream') ||
        path.startsWith('stream-');
  }

  Uint8List? _safeBase64Decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      var cleaned = raw.trim();
      if (cleaned.contains(',')) {
        cleaned = cleaned.substring(cleaned.indexOf(',') + 1).trim();
      }
      cleaned = cleaned.replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
      final remainder = cleaned.length % 4;
      if (remainder > 0) {
        cleaned = cleaned.padRight(cleaned.length + (4 - remainder), '=');
      }
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = widget.borderRadius ?? BorderRadius.circular(10);

    Widget? mediaContent;

    // 1. Check stored Base64 thumbnail
    final base64Bytes = _safeBase64Decode(r.thumbnailBase64);
    if (base64Bytes != null && base64Bytes.isNotEmpty) {
      mediaContent = Image.memory(
        base64Bytes,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (ctx, err, st) => _buildPlaceholder(context),
      );
    }

    // 2. Check asynchronously extracted video thumbnail
    if (mediaContent == null && _asyncVideoThumb != null && _asyncVideoThumb!.isNotEmpty) {
      mediaContent = Image.memory(
        _asyncVideoThumb!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (ctx, err, st) => _buildPlaceholder(context),
      );
    }

    // 3. Check suspicious frames list for frame thumbnail
    if (mediaContent == null && r.suspiciousFrames != null && r.suspiciousFrames!.isNotEmpty) {
      for (final frame in r.suspiciousFrames!) {
        final frameB64 = frame['thumbnailBase64'] ?? frame['base64'] ?? frame['image'];
        if (frameB64 is String && frameB64.isNotEmpty) {
          final fBytes = _safeBase64Decode(frameB64);
          if (fBytes != null && fBytes.isNotEmpty) {
            mediaContent = Image.memory(
              fBytes,
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
              errorBuilder: (ctx, err, st) => _buildPlaceholder(context),
            );
            break;
          }
        }
        final framePath = frame['framePath'] ?? frame['path'];
        if (framePath is String && framePath.isNotEmpty && File(framePath).existsSync()) {
          mediaContent = Image.file(
            File(framePath),
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (ctx, err, st) => _buildPlaceholder(context),
          );
          break;
        }
        final frameUrl = frame['imageUrl'] ?? frame['url'];
        if (frameUrl is String && frameUrl.startsWith('http')) {
          mediaContent = CachedNetworkImage(
            imageUrl: frameUrl,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            placeholder: (ctx, u) => _buildLoadingShimmer(),
            errorWidget: (ctx, u, e) => _buildPlaceholder(context),
          );
          break;
        }
      }
    }

    // 4. Check local file path on disk (Local image or cached video frame)
    if (mediaContent == null && r.mediaPath != null && r.mediaPath!.isNotEmpty) {
      final file = File(r.mediaPath!);
      if (file.existsSync()) {
        if (_isImageFile(r.mediaPath!) || _isImageModality(r)) {
          mediaContent = Image.file(
            file,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (ctx, err, st) => _buildPlaceholder(context),
          );
        }
      }
    }

    // 5. Check YouTube video link thumbnail
    if (mediaContent == null) {
      final ytThumbUrl = VeriMediaPreview.getYoutubeThumbnailUrl(r.videoUrl) ??
          VeriMediaPreview.getYoutubeThumbnailUrl(r.mediaPath) ??
          VeriMediaPreview.getYoutubeThumbnailUrl(r.mediaName);
      if (ytThumbUrl != null) {
        mediaContent = CachedNetworkImage(
          imageUrl: ytThumbUrl,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          placeholder: (ctx, u) => _buildLoadingShimmer(),
          errorWidget: (ctx, u, e) => _buildPlaceholder(context),
        );
      }
    }

    // 6. Check Direct HTTP/HTTPS Image link
    if (mediaContent == null) {
      final candidateUrl = (r.videoUrl != null && r.videoUrl!.startsWith('http'))
          ? r.videoUrl
          : ((r.mediaPath != null && r.mediaPath!.startsWith('http'))
              ? r.mediaPath
              : ((r.mediaName != null && r.mediaName!.startsWith('http')) ? r.mediaName : null));

      if (candidateUrl != null && (_isImageModality(r) || _isImageFile(candidateUrl))) {
        mediaContent = CachedNetworkImage(
          imageUrl: candidateUrl,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          placeholder: (ctx, u) => _buildLoadingShimmer(),
          errorWidget: (ctx, u, e) => _buildPlaceholder(context),
        );
      }
    }

    // 7. If currently extracting async thumbnail, show shimmer
    if (mediaContent == null && _isLoadingAsyncThumb) {
      mediaContent = _buildLoadingShimmer();
    }

    // 8. If still null, render the styled modality placeholder
    mediaContent ??= _buildPlaceholder(context);

    final isLiveStream = _isLiveStreamModality(r);
    final isImage = _isImageModality(r);
    final isAudio = _isAudioModality(r);
    final isVideo = !isImage && !isAudio;

    final durationText = (r.videoLength != null && r.videoLength!.isNotEmpty)
        ? r.videoLength!
        : (isLiveStream ? 'LIVE' : null);

    Widget resultWidget = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? (isDark ? const Color(0xFF141C2E) : const Color(0xFFF1F5F9)),
        borderRadius: radius,
        border: Border.all(
          color: isDark ? const Color(0xFF26334D) : const Color(0xFFE2E8F0),
          width: 0.9,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: mediaContent),

            // Subtle dark overlay to give high contrast for badges and buttons
            if (mediaContent is! _PlaceholderBox && (widget.showPlayBadge || widget.showLiveBadge))
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),

            // Live stream badge in top corner
            if (isLiveStream && widget.showLiveBadge)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3.5),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Center Action / Play / Inspect Circle
            if (widget.showPlayBadge && !isAudio)
              Center(
                child: Container(
                  width: (widget.width != null && widget.width! < 90) ? 26 : 34,
                  height: (widget.width != null && widget.width! < 90) ? 26 : 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isImage
                        ? Icons.remove_red_eye_rounded
                        : (isLiveStream ? Icons.sensors_rounded : Icons.play_arrow_rounded),
                    color: Colors.white,
                    size: (widget.width != null && widget.width! < 90) ? 14 : 19,
                  ),
                ),
              ),

            // Audio Center Icon
            if (widget.showPlayBadge && isAudio)
              Center(
                child: Container(
                  width: (widget.width != null && widget.width! < 90) ? 26 : 34,
                  height: (widget.width != null && widget.width! < 90) ? 26 : 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
                ),
              ),

            // Video duration pill
            if (widget.showDuration && isVideo && durationText != null && durationText.isNotEmpty)
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    durationText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.onTap != null) {
      resultWidget = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onTap,
          child: resultWidget,
        ),
      );
    }

    return resultWidget;
  }

  Widget _buildLoadingShimmer() {
    return Container(
      color: Colors.black12,
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final r = widget.report;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vUpper = r.verdict.toUpperCase();
    final isReal = vUpper == 'AUTHENTIC';
    final isManipulated = vUpper == 'MANIPULATED' || vUpper == 'FAKE' || vUpper == 'LIKELY_FAKE';

    IconData icon;
    Color accentColor;

    if (_isAudioModality(r)) {
      icon = Icons.graphic_eq_rounded;
      accentColor = const Color(0xFF8B5CF6);
    } else if (_isLiveStreamModality(r)) {
      icon = Icons.sensors_rounded;
      accentColor = const Color(0xFFEF4444);
    } else if (_isImageModality(r)) {
      icon = isReal ? Icons.image_rounded : Icons.broken_image_rounded;
      accentColor = isReal ? const Color(0xFF10B981) : (isManipulated ? const Color(0xFFEF4444) : const Color(0xFF0EA5E9));
    } else {
      // Video
      icon = isReal ? Icons.videocam_rounded : Icons.movie_filter_rounded;
      accentColor = isReal ? const Color(0xFF10B981) : (isManipulated ? const Color(0xFFEF4444) : const Color(0xFF2563EB));
    }

    return _PlaceholderBox(
      isDark: isDark,
      accentColor: accentColor,
      icon: icon,
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  final bool isDark;
  final Color accentColor;
  final IconData icon;

  const _PlaceholderBox({
    required this.isDark,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  accentColor.withValues(alpha: 0.22),
                  const Color(0xFF0F1523),
                ]
              : [
                  accentColor.withValues(alpha: 0.14),
                  Colors.white,
                ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: accentColor,
          size: 26,
        ),
      ),
    );
  }
}
