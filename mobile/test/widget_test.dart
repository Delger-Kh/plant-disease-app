import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/main.dart';
import 'package:plant_doctor/models.dart';
import 'package:plant_doctor/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Угтах дэлгэц → Эхлэх → нэвтрэх форм', (tester) async {
    useGoogleFonts = false; // тестийн орчинд фонт татахгүй
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PlantDoctorApp());
    await tester.pumpAndSettle();
    expect(find.text('Ургамлын эмч'), findsOneWidget);
    await tester.tap(find.text('Эхлэх'));
    await tester.pumpAndSettle();
    expect(find.text('Нэвтрэх'), findsWidgets);
    expect(find.text('Бүртгэлгүй юу?'), findsOneWidget);
    expect(find.text('Бүртгүүлэх'), findsOneWidget);
  });

  test('Оношийн JSON-г зөв уншина', () {
    final d = Diagnosis.fromJson({
      'id': 1,
      'created_at': '2026-11-20T10:00:00Z',
      'status': 'ai_done',
      'status_label': 'AI оношилсон',
      'confidence': 0.97,
      'affected_pct': 12.5,
      'severity': 'Бага',
      'message': 'Улаан лоолийн эрт хорчилт илэрлээ.',
      'note': '',
      'image_url': '/media/a.jpg',
      'overlay_url': '/media/a_overlay.jpg',
      'disease': {
        'id': 3,
        'key': 'Tomato___Early_blight',
        'plant': 'Улаан лооль',
        'name_mn': 'Улаан лоолийн эрт хорчилт',
        'name_en': 'Tomato early blight',
        'is_healthy': false,
        'pathogen': 'Alternaria solani',
        'symptoms': '',
        'description': '',
        'prevention': '',
        'treatments': [
          {'id': 1, 'method': 'Зэсийн бэлдмэл', 'is_organic': true, 'instructions': '7 хоног тутам'}
        ],
      },
      'top_predictions': [
        {'key': 'Tomato___Early_blight', 'name_mn': 'Эрт хорчилт', 'plant': 'Улаан лооль', 'confidence': 0.97}
      ],
      'warnings': [],
      'user_name': 'Оюумаа',
    });
    expect(d.title, 'Улаан лоолийн эрт хорчилт');
    expect(d.disease!.treatments.single.isOrganic, isTrue);
    expect(d.needsReview, isFalse);
    expect(d.topPredictions.first.confidence, closeTo(0.97, 1e-9));
  });
}
