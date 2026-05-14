import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../views/widgets/primary_button.dart';
import 'phone_login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _illustrationScale;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _illustrationScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _bounceAnim = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutBack),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _buildIllustration(),
                  const Spacer(flex: 2),
                  _buildContent(),
                  const Spacer(),
                  _buildCTA(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return AnimatedBuilder(
      animation: _bounceAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _bounceAnim.value),
        child: child,
      ),
      child: ScaleTransition(
        scale: _illustrationScale,
        child: Container(
          width: double.infinity,
          height: 280,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primarySoft,
                AppColors.accent.withOpacity(0.08),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background decorative elements
              Positioned(
                top: 20,
                right: 30,
                child: _glassCircle(70, AppColors.primary.withOpacity(0.08)),
              ),
              Positioned(
                bottom: 30,
                left: 20,
                child: _glassCircle(90, AppColors.accent.withOpacity(0.06)),
              ),
              Positioned(
                top: 60,
                left: 40,
                child: _glassCircle(30, AppColors.accent.withOpacity(0.05)),
              ),
              // Chat bubbles illustration
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chatBubble('Hey! How are you? 👋', true),
                  const SizedBox(height: 12),
                  _chatBubble("I'm great! Let's chat 🚀", false),
                  const SizedBox(height: 12),
                  _chatBubble('NovaChat is amazing! ✨', true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _chatBubble(String text, bool isRight) {
    return Align(
      alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isRight ? 50 : 16,
          right: isRight ? 16 : 50,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isRight ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isRight ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Text(
          'Connect instantly\nwith NovaChat',
          textAlign: TextAlign.center,
          style: AppTextStyles.displayMedium,
        ),
        const SizedBox(height: 14),
        const Text(
          'Fast, secure, and beautiful messaging\nfor everyone, everywhere.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _featureChip('🔒 End-to-end encryption'),
            const SizedBox(width: 8),
            _featureChip('⚡ Real-time'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _featureChip('💬 Unlimited messages'),
            const SizedBox(width: 8),
            _featureChip('🖼️ Media sharing'),
          ],
        ),
      ],
    );
  }

  Widget _featureChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCTA() {
    return PrimaryButton(
      label: 'Get Started',
      icon: Icons.arrow_forward_rounded,
      onPressed: () => Navigator.of(context).push(
        AppUtils.slideRoute(const PhoneLoginScreen()),
      ),
    );
  }
}