import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../utils/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double radius;
  final bool showOnline;
  final bool isOnline;

  const UserAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.radius = 24,
    this.showOnline = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primarySoft,
          child: imageUrl.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Shimmer.fromColors(
                      baseColor: AppColors.shimmerBase,
                      highlightColor: AppColors.shimmerHighlight,
                      child: Container(
                        width: radius * 2,
                        height: radius * 2,
                        color: AppColors.shimmerBase,
                      ),
                    ),
                    errorWidget: (_, __, ___) => _initials(),
                  ),
                )
              : _initials(),
        ),
        if (showOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.55,
              height: radius * 0.55,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.online : AppColors.offline,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _initials() {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Text(
      initial,
      style: TextStyle(
        fontSize: radius * 0.7,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    );
  }
}
