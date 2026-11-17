import 'package:alerta_sismica/services/password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hasher = PasswordHasher(iteraciones: 100);

  group('PasswordHasher', () {
    test('deriva el mismo hash para la misma contraseña y sal', () {
      const sal = 'c2FsZGUgZGUgcHJ1ZWJh';
      final primero = hasher.derivar('Clave12345', sal);
      final segundo = hasher.derivar('Clave12345', sal);

      expect(primero, segundo);
      expect(primero, isNot(contains('Clave12345')));
    });

    test('cambia el hash con otra sal', () {
      final a = hasher.derivar('Clave12345', 'c2FsdW5v');
      final b = hasher.derivar('Clave12345', 'c2FsZG9z');

      expect(a, isNot(b));
    });

    test('verifica correctamente contraseñas', () {
      const sal = 'c2FsZGUgZGUgcHJ1ZWJh';
      final hash = hasher.derivar('Clave12345', sal);

      expect(hasher.verificar('Clave12345', sal, hash), isTrue);
      expect(hasher.verificar('Clave54321', sal, hash), isFalse);
    });

    test('genera códigos de recuperación de 12 caracteres', () {
      final codigo = hasher.generarCodigoRecuperacion();

      expect(codigo.length, 12);
      expect(RegExp(r'^[A-Z0-9]+$').hasMatch(codigo), isTrue);
      expect(hasher.generarCodigoRecuperacion(), isNot(codigo));
    });

    test('formatea el código en bloques de cuatro caracteres', () {
      expect(hasher.formatearCodigo('abcd-efgh-jklm'), 'ABCD-EFGH-JKLM');
      expect(hasher.formatearCodigo('corto'), 'CORTO');
    });

    test('genera tokens URL-safe distintos', () {
      final token = hasher.generarToken();

      expect(token.length, greaterThan(20));
      expect(RegExp(r'^[A-Za-z0-9_-]+=*$').hasMatch(token), isTrue);
      expect(hasher.generarToken(), isNot(token));
    });
  });
}
