import 'package:flutter_test/flutter_test.dart';
import 'package:looped_app/services/motion_scoring_service.dart';

/// Los pasos del podómetro entran por un camino distinto al del acelerómetro
/// y durante un tiempo se saltearon el tope y la penalización anti-trampa.
/// Estos tests fijan ese comportamiento.
void main() {
  group('addPedometerPoints', () {
    late MotionScoringService svc;

    setUp(() {
      svc = MotionScoringService();
      // reset() fija _startTime, que es contra lo que se mide el tope.
      svc.reset();
    });

    test('ignora tandas vacías o negativas', () {
      svc.addPedometerPoints(0);
      svc.addPedometerPoints(-5);
      expect(svc.currentPoints, 0);
    });

    test('acredita una tanda normal completa', () {
      svc.addPedometerPoints(7);
      expect(svc.currentPoints, 7);
    });

    test('capea una tanda imposible al techo de la sesión', () {
      // Recién arrancada, el techo es la gracia inicial (2s) por 8 pts/seg.
      svc.addPedometerPoints(100000);
      expect(svc.currentPoints, lessThanOrEqualTo(16));
      expect(svc.currentPoints, greaterThan(0));
    });

    test('el tope es acumulativo: varias tandas no lo superan entre todas', () {
      for (var i = 0; i < 20; i++) {
        svc.addPedometerPoints(50);
      }
      // Sin importar cuántas veces entren, el total sigue atado al tiempo.
      expect(svc.currentPoints, lessThanOrEqualTo(16));
    });

    test('no descuenta puntos ya acreditados cuando la tanda se capea', () {
      svc.addPedometerPoints(5);
      final antes = svc.currentPoints;
      svc.addPedometerPoints(100000);
      expect(svc.currentPoints, greaterThanOrEqualTo(antes));
    });

    test('marca que hay movimiento al acreditar', () {
      expect(svc.isDancing, isFalse);
      svc.addPedometerPoints(3);
      expect(svc.isDancing, isTrue);
    });

    test('reset vuelve a cero el total y el tope acumulado', () {
      svc.addPedometerPoints(100000);
      expect(svc.currentPoints, greaterThan(0));
      svc.reset();
      expect(svc.currentPoints, 0);
      // Y después del reset se puede volver a acreditar desde cero.
      svc.addPedometerPoints(4);
      expect(svc.currentPoints, 4);
    });
  });
}
