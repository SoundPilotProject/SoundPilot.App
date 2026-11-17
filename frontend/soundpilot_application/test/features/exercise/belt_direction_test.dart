// test/features/exercise/belt_direction_test.dart
//
// The belt's half of the direction engine: which motors run for a direction,
// and for the obstacles standing around the user.

import 'package:flutter_test/flutter_test.dart';

import 'package:soundpilot_application/features/exercise/belt_direction.dart';

void main() {
  // Eight motors, one every 45°: motor 0 in front, then clockwise.
  const belt = BeltSectors();

  group('forDirection', () {
    test('a direction straight at a motor runs that one alone', () {
      expect(belt.forDirection(0), [1, 0, 0, 0, 0, 0, 0, 0]);
      expect(belt.forDirection(90), [0, 0, 1, 0, 0, 0, 0, 0]);
      expect(belt.forDirection(180), [0, 0, 0, 0, 1, 0, 0, 0]);
      expect(belt.forDirection(270), [0, 0, 0, 0, 0, 0, 1, 0]);
    });

    test('a direction between two motors is shared by both of them', () {
      final motors = belt.forDirection(22.5);

      expect(motors[0], closeTo(0.5, 1e-12));
      expect(motors[1], closeTo(0.5, 1e-12));
      expect(motors.skip(2), everyElement(0));
    });

    test('a quarter of the way over moves a quarter of the strength', () {
      final motors = belt.forDirection(45 + 11.25);

      expect(motors[1], closeTo(0.75, 1e-12));
      expect(motors[2], closeTo(0.25, 1e-12));
    });

    test('wraps around the back', () {
      // −45° is 315°, which is the last motor.
      expect(belt.forDirection(-45)[7], 1);
      expect(belt.forDirection(405), belt.forDirection(45));

      final shared = belt.forDirection(337.5);
      expect(shared[7], closeTo(0.5, 1e-12));
      expect(shared[0], closeTo(0.5, 1e-12));
    });

    test('the intensity scales the motors and is never doubled', () {
      final motors = belt.forDirection(22.5, intensity: 0.6);

      expect(motors[0], closeTo(0.3, 1e-12));
      expect(motors[1], closeTo(0.3, 1e-12));
      // Spread over the two, not added on top of each other.
      expect(motors.reduce((a, b) => a + b), closeTo(0.6, 1e-12));
    });

    test('nothing runs at intensity 0', () {
      expect(belt.forDirection(22.5, intensity: 0), everyElement(0));
    });

    test('a belt with more motors is narrower per motor', () {
      const wide = BeltSectors(motorCount: 12);

      expect(wide.motorAngle, 30);
      expect(wide.forDirection(30), [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    });
  });

  group('closeness', () {
    test('is 1 at the user and 0 at the warning distance', () {
      expect(BeltSectors.closeness(0, 200), 1);
      expect(BeltSectors.closeness(200, 200), 0);
      expect(BeltSectors.closeness(100, 200), closeTo(0.5, 1e-12));
    });

    test('nothing beyond the warning distance is felt', () {
      expect(BeltSectors.closeness(500, 200), 0);
    });

    test('a warning distance of 0 switches the belt off instead of dividing',
        () {
      expect(BeltSectors.closeness(10, 0), 0);
    });
  });

  group('forObstacles', () {
    test('one obstacle vibrates in its own direction, the closer the stronger',
        () {
      final far = belt.forObstacles(
        const [BeltObstacle(angle: 90, distanceCm: 150)],
        warningDistanceCm: 200,
      );
      final near = belt.forObstacles(
        const [BeltObstacle(angle: 90, distanceCm: 50)],
        warningDistanceCm: 200,
      );

      expect(far[2], closeTo(0.25, 1e-12));
      expect(near[2], closeTo(0.75, 1e-12));
      expect(near.where((motor) => motor > 0).length, 1);
    });

    test('two obstacles each reach their own side', () {
      final motors = belt.forObstacles(
        const [
          BeltObstacle(angle: 90, distanceCm: 100),
          BeltObstacle(angle: 270, distanceCm: 50),
        ],
        warningDistanceCm: 200,
      );

      expect(motors[2], closeTo(0.5, 1e-12));
      expect(motors[6], closeTo(0.75, 1e-12));
      expect(motors[0], 0);
      expect(motors[4], 0);
    });

    test('the nearest obstacle of a direction decides, they are not summed',
        () {
      final motors = belt.forObstacles(
        const [
          BeltObstacle(angle: 0, distanceCm: 180),
          BeltObstacle(angle: 0, distanceCm: 100),
          BeltObstacle(angle: 0, distanceCm: 160),
        ],
        warningDistanceCm: 200,
      );

      // Two far ones must not add up to a near one.
      expect(motors[0], closeTo(0.5, 1e-12));
    });

    test('obstacles beyond the warning distance are left out', () {
      final motors = belt.forObstacles(
        const [BeltObstacle(angle: 90, distanceCm: 400)],
        warningDistanceCm: 200,
      );

      expect(motors, everyElement(0));
    });

    test('the belt strength scales everything', () {
      final motors = belt.forObstacles(
        const [BeltObstacle(angle: 90, distanceCm: 100)],
        warningDistanceCm: 200,
        intensity: 0.5,
      );

      expect(motors[2], closeTo(0.25, 1e-12));
    });

    test('nothing at all is quiet', () {
      expect(
        belt.forObstacles(const [], warningDistanceCm: 200),
        everyElement(0),
      );
    });
  });
}
