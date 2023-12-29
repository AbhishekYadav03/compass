import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CompassApp(),
    );
  }
}

class CompassApp extends StatefulWidget {
  const CompassApp({super.key});

  @override
  State<CompassApp> createState() => _CompassAppState();
}

class _CompassAppState extends State<CompassApp> with TickerProviderStateMixin {
  bool _hasPermissions = false;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this);
  }

  void _fetchPermissionStatus() {
    Permission.locationWhenInUse.status.then((status) {
      if (mounted) {
        setState(() => _hasPermissions = status == PermissionStatus.granted);
      }
    });
  }

  double headingToDegree(double heading) {
    return heading < 0 ? 360 - heading.abs() : heading;
  }

  var oldIndex = 0;
  String getDirection(double angle) {
    var directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    var index = (((angle %= 360) < 0 ? angle + 360 : angle) / 45).round() % 8;
    if (index != oldIndex) {
      if (index % 2 == 0) {
        HapticFeedback.mediumImpact();
        oldIndex = index;
      } else {
        HapticFeedback.lightImpact();
        oldIndex = index;
      }
    }
    return directions[index];
  }

  late AnimationController controller;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        // backgroundColor: Colors.transparent,
        title: const Text('Compass'),
      ),
      body: StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, value) {
            double degrees = 0.0;
            if (value.hasData) {
              degrees = value.data?.heading ?? 0;
            }

            return Stack(
              children: [
                Neumorphism(
                  margin: EdgeInsets.all(size.width * 0.1),
                  padding: const EdgeInsets.all(1),
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (BuildContext context, Widget? child) {
                      return Transform.rotate(angle: (degrees * (pi / 180) * (-1)), child: child!);
                    },
                    child: CustomPaint(
                      size: size,
                      painter: CompassPainter(),
                    ),
                  ),
                ),
                Neumorphism(
                  innerShadow: true,
                  distance: 2.5,
                  margin: EdgeInsets.all(size.width * 0.30),
                  child: Neumorphism(
                    distance: 0,
                    blur: 0,
                    innerShadow: true,
                    isReverse: true,
                    margin: EdgeInsets.all(size.width * 0.01),
                    child: Neumorphism(
                      margin: EdgeInsets.all(size.width * 0.05),
                      distance: 4,
                      blur: 5,
                      child: TopGradient(
                        padding: EdgeInsets.all(size.width * 0.02),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xffBAC9AB),
                            shape: BoxShape.circle,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${(headingToDegree(degrees)).toStringAsFixed(0)}°",
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                getDirection(headingToDegree(degrees)),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            );
          }),
    );
  }
}

class CompassPainter extends CustomPainter {
  final int majorTickCount;
  final int minorTickCount;
  final Map<int, String> cardinalityMap;

  CompassPainter({
    this.majorTickCount = 18,
    this.minorTickCount = 90,
    this.cardinalityMap = const {0: "N", 90: 'E', 180: 'S', 270: 'W'},
  });

  final Paint majorPaint = Paint()
    ..strokeWidth = 2
    ..color = Colors.grey
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final Paint minorPaint = Paint()
    ..strokeWidth = 2
    ..color = Colors.grey.withOpacity(0.6)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final TextStyle majorTextStyle = const TextStyle(
    color: Colors.black,
    fontSize: 12,
  );
  final TextStyle cardinalityTextStyle = const TextStyle(
    color: Colors.black,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  late final _majorTicks = _ticksAngle(majorTickCount);
  late final _minorTicks = _ticksAngle(minorTickCount);
  late final _angleText = _ticksAngleText(_majorTicks);

  @override
  void paint(Canvas canvas, Size size) {
    double radius = size.width / 2;
    Offset center = size.center(Offset.zero);

    final majorTickLength = size.width * 0.08;
    final minorTickLength = size.width * 0.055;
    canvas.drawCircle(center, 3, majorPaint);

    for (final angle in _majorTicks) {
      final tickStart = Offset.fromDirection(angle.toCorrectRadians, radius);
      final tickEnd = Offset.fromDirection(angle.toCorrectRadians, radius - majorTickLength);
      canvas.drawLine(tickStart + center, center + tickEnd, majorPaint);
    }
    for (final angle in _minorTicks) {
      final tickStart = Offset.fromDirection(angle.toCorrectRadians, radius);
      final tickEnd = Offset.fromDirection(angle.toCorrectRadians, radius - minorTickLength);
      canvas.drawLine(tickStart + center, center + tickEnd, minorPaint);
    }

    for (final angle in _angleText) {
      var textPadding = majorTickLength + (size.width * 0.01);

      final textPainter = TextSpan(
        text: angle.toStringAsFixed(0),
        style: majorTextStyle,
      ).toPainter()
        ..layout();

      var layoutOffset = Offset.fromDirection(angle.toCorrectRadians, radius - textPadding);

      var offset = center + layoutOffset;

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(angle.toRadians);
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);

      // canvas.drawLine(layoutOffset + center, center, majorPaint);

      textPainter.paint(canvas, const Offset(0, 0));
      canvas.restore();
    }

    // for (final angle in _angleText) {
    //   var textPadding = majorTickLength - (size.width * 0.02);
    //
    //   final textPainter = TextSpan(
    //     text: angle.toStringAsFixed(0),
    //     style: majorTextStyle,
    //   ).toPainter()
    //     ..layout();
    //
    //   var layoutOffset = Offset.fromDirection(angle.toCorrectRadians, radius - textPadding);
    //   var offset = center + layoutOffset;
    //   canvas.restore();
    //
    //   canvas.save();
    //
    //   canvas.translate(offset.dx, offset.dy);
    //   canvas.rotate(angle.toRadians);
    //   canvas.translate(-offset.dx, -offset.dy);
    //
    //   canvas.drawLine(layoutOffset + center, center, majorPaint);
    //
    //   textPainter.paint(canvas, Offset(offset.dx - (textPainter.width / 2), offset.dy));
    // }

    for (final cardinality in cardinalityMap.entries) {
      var textPadding = majorTickLength + (size.width * 0.06);
      var angle = cardinality.key;
      var text = cardinality.value;

      final textPainter = TextSpan(
        text: text,
        style: cardinalityTextStyle.copyWith(color: text == 'N' ? Colors.red : null),
      ).toPainter()
        ..layout();

      var layoutOffset = Offset.fromDirection(angle.toCorrectRadians, radius - textPadding);

      var offset = center + layoutOffset;

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(angle.toRadians);
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);

      textPainter.paint(canvas, const Offset(0, 0));
      canvas.restore();
    }
  }

  List<double> _ticksAngle(int ticks) {
    final scale = 360 / ticks;
    return List.generate(ticks, (index) => index * scale);
  }

  List<double> _ticksAngleText(List<double> ticks) {
    List<double> angles = [];
    for (var i = 0; i < ticks.length; i++) {
      if (i == ticks.length - 1) {
        double degree = (ticks[i] + 360) / 2;
        angles.add(degree);
      } else {
        double degree = (ticks[i] + ticks[i + 1]) / 2;
        angles.add(degree);
      }
    }
    return angles;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

extension on num {
  double get toRadians => (this * pi) / 180;

  double get toCorrectRadians => ((this - 90) * pi) / 180;
}

extension on TextSpan {
  TextPainter toPainter({TextDirection textDirection = TextDirection.ltr}) {
    return TextPainter(text: this, textDirection: textDirection);
  }
}

class Neumorphism extends StatelessWidget {
  const Neumorphism({
    super.key,
    required this.child,
    this.distance = 30,
    this.blur = 50,
    this.margin,
    this.padding,
    this.isReverse = false,
    this.innerShadow = false,
  });

  final Widget child;
  final double distance;
  final double blur;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool isReverse;
  final bool innerShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xffdfddd7),
        shape: BoxShape.circle,
        boxShadow: isReverse
            ? [
                BoxShadow(
                  color: Colors.grey,
                  blurRadius: blur,
                  offset: Offset(-distance, -distance),
                ), // BoxShadow
                BoxShadow(
                  color: Colors.white,
                  blurRadius: blur,
                  offset: Offset(distance, distance),
                ), // BoxShadow
              ]
            : [
                BoxShadow(
                  color: Colors.white,
                  blurRadius: blur,
                  offset: Offset(-distance, -distance),
                ), // BoxShadow
                BoxShadow(
                  color: Colors.grey,
                  blurRadius: blur,
                  offset: Offset(distance, distance),
                ), // BoxShadow
              ],
      ),
      child: innerShadow ? TopGradient(child: child) : child,
    ); // Container
  }
}

class TopGradient extends StatelessWidget {
  const TopGradient({
    super.key,
    required this.child,
    this.margin,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey,
            Colors.white,
          ],
        ),
      ),
      child: child,
    );
  }
}
