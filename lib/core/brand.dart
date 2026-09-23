import 'package:flutter/material.dart';

const appName = 'ImpactLab';
const brandLogoAsset = 'assets/branding/impactlab-logo.jpeg';

/// Preserves the supplied logo's aspect ratio and includes its wordmark.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    this.height = 56,
    this.excludeFromSemantics = false,
    super.key,
  });
  final double height;
  final bool excludeFromSemantics;
  @override
  Widget build(BuildContext context) => Image.asset(
    brandLogoAsset,
    height: height,
    width: height * 976 / 1154,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    semanticLabel: excludeFromSemantics ? null : 'Logo ImpactLab',
    excludeFromSemantics: excludeFromSemantics,
  );
}

const brandNavy = Color(0xFF04122D);
const brandCyan = Color(0xFF27D8F4);
const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [brandNavy, Color(0xFF0A326B)],
);

class BrandHero extends StatelessWidget {
  const BrandHero({required this.onExplore, super.key});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      gradient: brandGradient,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: brandCyan.withValues(alpha: .25)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxWidth >= 610;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'APRENDER. PARTICIPAR. TRANSFORMAR.',
              style: TextStyle(
                color: Color(0xFF85E7F6),
                fontSize: 10,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Seu aprendizado\nilumina o caminho.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 31,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Organize seus planos, participe de missões e celebre cada nova conquista.',
              style: TextStyle(color: Color(0xFFD6E7FB), height: 1.7),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: brandCyan,
                foregroundColor: brandNavy,
              ),
              onPressed: onExplore,
              label: const Text('Explorar missões'),
              icon: const Icon(Icons.arrow_forward, size: 18),
            ),
          ],
        );
        return roomy
            ? Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 22),
                  const BrandLogo(height: 228),
                ],
              )
            : text;
      },
    ),
  );
}
