import 'package:flutter/material.dart';
import '../models/workout.dart';

class ExerciseDetailsScreen extends StatelessWidget {
  const ExerciseDetailsScreen({super.key});

  static const _bgDark = Color.fromARGB(255, 18, 32, 47);
  static const _ink = Color(0xFF051328);

  @override
  Widget build(BuildContext context) {
    final arg = ModalRoute.of(context)?.settings.arguments;
    final Workout? workout = (arg is Workout) ? arg : null;

    return Scaffold(
      backgroundColor: _bgDark,
      body: Center(
        child: LayoutBuilder(
          builder: (context, c) {
            final cardW = (c.maxWidth * 0.92).clamp(320.0, 375.0);
            final cardH = cardW * (812 / 375);
            final s = cardW / 375;

            return ClipRRect(
              borderRadius: BorderRadius.circular(40 * s),
              child: Container(
                width: cardW,
                height: cardH,
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(24 * s, 36 * s, 24 * s, 24 * s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.arrow_back_rounded, color: _ink, size: 28 * s),
                    ),
                    SizedBox(height: 18 * s),
                    Text(
                      workout?.title ?? 'Exercise Details',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 26 * s,
                        fontFamily: 'DM Sans',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8 * s),
                    Text(
                      workout?.subtitle ?? 'No workout received (route arguments missing).',
                      style: TextStyle(
                        color: _ink.withValues(alpha: 0.65),
                        fontSize: 14 * s,
                        fontFamily: 'DM Sans',
                      ),
                    ),
                    SizedBox(height: 18 * s),

                    if (workout != null) ...[
                      Text(
                        'Benefits',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 14 * s,
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8 * s),
                      for (final b in workout.benefits)
                        Padding(
                          padding: EdgeInsets.only(bottom: 6 * s),
                          child: Text(
                            '• $b',
                            style: TextStyle(
                              color: _ink.withValues(alpha: 0.70),
                              fontSize: 13 * s,
                              fontFamily: 'DM Sans',
                            ),
                          ),
                        ),
                    ],

                    const Spacer(),
                    Text(
                      'Put your exercise logic here.',
                      style: TextStyle(
                        color: _ink.withValues(alpha: 0.60),
                        fontSize: 14 * s,
                        fontFamily: 'DM Sans',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
