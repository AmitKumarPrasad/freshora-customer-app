import 'package:flutter/material.dart';

import 'widgets/freshora_logo.dart';

const _forest = Color(0xFF173B2E);
const _cream = Color(0xFFFAF7EF);
const _orange = Color(0xFFFFB477);

class TalegaonLandingPage extends StatelessWidget {
  const TalegaonLandingPage({
    super.key,
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: _cream,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        compact ? 20 : 40, 20, compact ? 20 : 40, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const FreshoraLogo(size: 43),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('FRESHORA',
                                    style: TextStyle(
                                        color: _forest,
                                        fontSize: 18,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w900)),
                                Text('THE LOCAL FRESH MARKET',
                                    style: TextStyle(
                                        color: Color(0xFF728578),
                                        fontSize: 9,
                                        letterSpacing: 1.8,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          TextButton(
                              onPressed: onSignIn,
                              child: const Text('Sign in',
                                  style: TextStyle(
                                      color: _forest,
                                      fontWeight: FontWeight.w800))),
                        ]),
                        SizedBox(height: compact ? 24 : 42),
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: _forest,
                            borderRadius:
                                BorderRadius.circular(compact ? 30 : 40),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x26173B2E),
                                  blurRadius: 32,
                                  offset: Offset(0, 18)),
                            ],
                          ),
                          child: compact
                              ? Column(children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        26, 30, 26, 0),
                                    child: _heroCopy(compact),
                                  ),
                                  const SizedBox(height: 12),
                                  const _ProduceScene(compact: true),
                                ])
                              : Row(children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(48),
                                      child: _heroCopy(compact),
                                    ),
                                  ),
                                  const Expanded(
                                      child: _ProduceScene(compact: false)),
                                ]),
                        ),
                        const SizedBox(height: 25),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: const [
                            _Promise(
                                icon: Icons.grass_rounded,
                                text: 'Picked fresh'),
                            _Promise(
                                icon: Icons.storefront_rounded,
                                text: 'From local sellers'),
                            _Promise(
                                icon: Icons.door_front_door_rounded,
                                text: 'To your doorstep'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );

  Widget _heroCopy(bool compact) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FRESH DAYS START HERE',
              style: TextStyle(
                  color: Color(0xFFFFD89A),
                  letterSpacing: 2.2,
                  fontSize: 11,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          Text.rich(
            const TextSpan(children: [
              TextSpan(text: 'Good food.\n'),
              TextSpan(text: 'Good mood.', style: TextStyle(color: _orange)),
            ]),
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
                fontSize: compact ? 40 : 58,
                height: 1.03,
                letterSpacing: -1.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'The everyday market for fresh produce and family favourites in Talegaon.',
            style:
                TextStyle(color: Color(0xFFD6E7D9), fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 25),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              onPressed: onCreateAccount,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: const Text('Explore the market'),
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: _forest,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            OutlinedButton(
              onPressed: onSignIn,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0x99FFFFFF)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Sign in'),
            ),
          ]),
        ],
      );
}

class _ProduceScene extends StatelessWidget {
  const _ProduceScene({required this.compact});

  final bool compact;

  Widget _produce(String image, double size, Color background) => Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * .38),
          boxShadow: const [
            BoxShadow(
                color: Color(0x44000000),
                blurRadius: 22,
                offset: Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * .32),
          child: Image.asset(image, fit: BoxFit.cover),
        ),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
        height: compact ? 240 : 430,
        child: LayoutBuilder(builder: (context, box) {
          final width = box.maxWidth;
          return Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned(
              width: compact ? 265 : 370,
              height: compact ? 265 : 370,
              right: compact ? -22 : -40,
              top: compact ? 10 : 28,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                    color: Color(0xFF2B6543), shape: BoxShape.circle),
              ),
            ),
            Positioned(
                top: compact ? 7 : 48,
                left: width * .28,
                child: Transform.rotate(
                    angle: -.15,
                    child: _produce('assets/images/products/tomatoes.png',
                        compact ? 105 : 148, const Color(0xFFFFE3C9)))),
            Positioned(
                top: compact ? 70 : 170,
                left: width * .05,
                child: Transform.rotate(
                    angle: .12,
                    child: _produce('assets/images/products/banana.png',
                        compact ? 104 : 140, const Color(0xFFFFEAA7)))),
            Positioned(
                top: compact ? 101 : 189,
                right: width * .08,
                child: Transform.rotate(
                    angle: .09,
                    child: _produce('assets/images/products/apples.png',
                        compact ? 108 : 150, const Color(0xFFFFD6C7)))),
            Positioned(
                right: width * .08,
                top: compact ? 15 : 51,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFD884),
                      borderRadius: BorderRadius.circular(30)),
                  child: const Text('FRESH PICKS',
                      style: TextStyle(
                          color: _forest,
                          letterSpacing: 1.2,
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                )),
          ]);
        }),
      );
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFE7EBDD)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: _forest),
          const SizedBox(width: 7),
          Text(text,
              style: const TextStyle(
                  color: _forest, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}
