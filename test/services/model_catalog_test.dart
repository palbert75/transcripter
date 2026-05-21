import 'package:flutter_test/flutter_test.dart';
import 'package:transcripter/services/model_catalog.dart';

void main() {
  test('catalog includes base.en and is non-empty', () {
    final ids = ModelCatalog.all.map((m) => m.id).toSet();
    expect(ids, contains('base.en'));
    expect(ModelCatalog.all, isNotEmpty);
  });

  test('every model maps to a HuggingFace ggerganov URL', () {
    for (final m in ModelCatalog.all) {
      final url = ModelCatalog.urlFor(m);
      expect(url.host, 'huggingface.co');
      expect(url.path, contains('ggerganov/whisper.cpp'));
      expect(url.path, endsWith(m.filename));
    }
  });

  test('English-only models are flagged correctly', () {
    final base = ModelCatalog.all.firstWhere((m) => m.id == 'base.en');
    expect(base.multilingual, isFalse);
    final multi = ModelCatalog.all.firstWhere((m) => m.id == 'base');
    expect(multi.multilingual, isTrue);
  });

  test('catalog includes large-v3 and medium multilingual options', () {
    final ids = ModelCatalog.all.map((m) => m.id).toSet();
    expect(ids, containsAll(<String>['medium', 'large-v3']));
    final large = ModelCatalog.all.firstWhere((m) => m.id == 'large-v3');
    expect(large.multilingual, isTrue);
    expect(large.description, contains('99 languages'));
  });
}
