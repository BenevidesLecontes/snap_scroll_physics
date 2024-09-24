library snap_scroll_physics;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:snap_scroll_physics/src/snap.dart';

export 'src/snap.dart';

const double _kNavBarLargeTitleHeightExtension = 52.0;

mixin _SnapScrollPhysics on ScrollPhysics {
  @override
  BaseSnapScrollPhysics applyTo(ScrollPhysics? ancestor);
}

abstract class SnapScrollPhysics extends ScrollPhysics with _SnapScrollPhysics {
  factory SnapScrollPhysics({
    ScrollPhysics? parent,
    List<Snap> snaps,
  }) = RawSnapScrollPhysics;

  factory SnapScrollPhysics.builder(
    SnapBuilder builder, {
    ScrollPhysics? parent,
  }) = BuilderSnapScrollPhysics;

  static final cupertinoAppBar = SnapScrollPhysics._forCupertinoAppBar();

  factory SnapScrollPhysics._forCupertinoAppBar() =
      CupertinoAppBarSnapScrollPhysics;

  factory SnapScrollPhysics.preventStopBetween(
    double minExtent,
    double maxExtent, {
    double? delimiter,
    ScrollPhysics? parent,
  }) {
    return SnapScrollPhysics(
      parent: parent,
      snaps: [
        Snap.avoidZone(minExtent, maxExtent, delimiter: delimiter),
      ],
    );
  }
}

class RawSnapScrollPhysics extends BaseSnapScrollPhysics {
  const RawSnapScrollPhysics({
    super.parent,
    this.snaps = const [],
  });

  @override
  final List<Snap> snaps;

  @override
  RawSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return RawSnapScrollPhysics(
      parent: buildParent(ancestor),
      snaps: snaps,
    );
  }
}

class CupertinoAppBarSnapScrollPhysics extends BaseSnapScrollPhysics {
  CupertinoAppBarSnapScrollPhysics({super.parent});

  @override
  final List<Snap> snaps = [
    Snap.avoidZone(0, _kNavBarLargeTitleHeightExtension),
  ];

  @override
  CupertinoAppBarSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CupertinoAppBarSnapScrollPhysics(
      parent: buildParent(ancestor),
    );
  }
}

typedef SnapBuilder = List<Snap> Function();

class BuilderSnapScrollPhysics extends BaseSnapScrollPhysics {
  const BuilderSnapScrollPhysics(this.builder, {super.parent});

  final SnapBuilder builder;

  @override
  List<Snap> get snaps => builder();

  @override
  BuilderSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return BuilderSnapScrollPhysics(
      builder,
      parent: buildParent(ancestor),
    );
  }
}

abstract class BaseSnapScrollPhysics extends ScrollPhysics
    implements SnapScrollPhysics {
  const BaseSnapScrollPhysics({super.parent});

  List<Snap> get snaps;

  double _getTargetPixels(
    ScrollMetrics position,
    double proposedEnd,
    Tolerance tolerance,
    double velocity,
  ) {
    final Snap? snap = getSnap(position, proposedEnd, tolerance, velocity);
    if (snap == null) return proposedEnd;

    return snap.targetPixelsFor(position, proposedEnd, tolerance, velocity);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final simulation = super.createBallisticSimulation(position, velocity);
    final proposedPixels = simulation?.x(double.infinity) ?? position.pixels;

    final tolerance = toleranceFor(position);

    final double target = _getTargetPixels(
      position,
      proposedPixels,
      tolerance,
      velocity,
    );
    if ((target - proposedPixels).abs() > precisionErrorTolerance) {
      if (simulation is BouncingScrollSimulation) {
        return BouncingScrollSimulation(
          leadingExtent: math.min(target, position.pixels),
          trailingExtent: math.max(target, position.pixels),
          velocity: velocity,
          position: position.pixels,
          spring: spring,
          tolerance: toleranceFor(position),
        );
      }
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return simulation;
  }

  @override
  bool get allowImplicitScrolling => false;

  Snap? getSnap(
    ScrollMetrics position,
    double proposedEnd,
    Tolerance tolerance,
    double velocity,
  ) {
    for (final snap in snaps) {
      if (snap.shouldApplyFor(position, proposedEnd)) return snap;
    }
    return null;
  }
}
