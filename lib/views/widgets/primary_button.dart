import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? color;
  final double? width;
  final double height;
  final double borderRadius;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.color,
    this.width,
    this.height = 54,
    this.borderRadius = 14,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _controller;
    _shimmerAnim = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: const Offset(1.5, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.reverse();
  void _onTapUp(_) => _controller.forward();

  @override
  Widget build(BuildContext context) {
    final colors = widget.onPressed == null
        ? [AppColors.textHint.withOpacity(0.5), AppColors.textHint.withOpacity(0.5)]
        : [
            widget.color ?? AppColors.primary,
            widget.color != null
                ? widget.color!.withOpacity(0.8)
                : AppColors.primaryLight,
          ];

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () => _controller.forward(),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: widget.onPressed == null
                ? []
                : [
                    BoxShadow(
                      color: (widget.color ?? AppColors.primary)
                          .withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: widget.isLoading
              ? Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (_, __) => SlideTransition(
                          position: _shimmerAnim,
                          child: FractionallySizedBox(
                            widthFactor: 0.3,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0),
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(widget.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          )),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}