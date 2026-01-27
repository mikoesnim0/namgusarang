class FoodEquivalent {
  const FoodEquivalent({
    required this.id,
    required this.kcalPerServing,
    required this.nameKr,
    required this.unitLabel,
    required this.iconKey,
    this.amountPerServing = 1,
  });

  final String id;
  final int kcalPerServing;
  final String nameKr;
  final num amountPerServing;
  final String unitLabel;
  final String iconKey;

  String get iconAssetPath => 'assets/icons/foods/$iconKey.png';
}

class FoodEquivalentResult {
  const FoodEquivalentResult({required this.food, required this.servings});

  final FoodEquivalent food;
  final int servings;

  num get totalAmount => servings * food.amountPerServing;

  String formatLabel() {
    final amountText = _formatNumber(totalAmount);
    return '${food.nameKr} $amountText${food.unitLabel}';
  }
}

FoodEquivalentResult? suggestFoodEquivalentForKcal(
  int kcal, {
  int minServings = 1,
  int maxServings = 9,
}) {
  if (kcal <= 0) return null;
  final foods = defaultFoodEquivalents
      .where((f) => f.kcalPerServing > 0)
      .toList(growable: false);
  if (foods.isEmpty) return null;

  final sorted = foods.toList()
    ..sort((a, b) => a.kcalPerServing - b.kcalPerServing);

  // Prefer a food that yields a "reasonable" servings count (minServings..maxServings)
  // and has the smallest remainder (closest fit).
  FoodEquivalent? bestFood;
  var bestServings = 0;
  var bestRemainder = 1 << 30;

  for (final food in sorted) {
    final servings = kcal ~/ food.kcalPerServing;
    if (servings < minServings || servings > maxServings) continue;

    final remainder = kcal - (servings * food.kcalPerServing);
    final isBetter =
        remainder < bestRemainder ||
        (remainder == bestRemainder &&
            (bestFood == null ||
                food.kcalPerServing < bestFood.kcalPerServing));

    if (!isBetter) continue;
    bestFood = food;
    bestServings = servings;
    bestRemainder = remainder;
  }

  if (bestFood == null) {
    // Fallback: pick the smallest food and show at least 1 serving.
    bestFood = sorted.first;
    bestServings = 1;
  }

  return FoodEquivalentResult(food: bestFood, servings: bestServings);
}

String _formatNumber(num n) {
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toStringAsFixed(1);
}

/// Default food table (kcal → food equivalent).
///
/// - `kcalPerServing`: calories for `amountPerServing` + `unitLabel`.
/// - Example: `kcalPerServing=300, amountPerServing=210, unitLabel='g'` means "쌀밥 210g = 300kcal".
///
/// Assets: place corresponding PNGs at `assets/icons/foods/{iconKey}.png`.
const defaultFoodEquivalents = <FoodEquivalent>[
  FoodEquivalent(
    id: 'gim',
    kcalPerServing: 20,
    nameKr: '조미김',
    amountPerServing: 1,
    unitLabel: '장',
    iconKey: 'Gim_ic',
  ),
  FoodEquivalent(
    id: 'almonds',
    kcalPerServing: 30,
    nameKr: '아몬드',
    amountPerServing: 4,
    unitLabel: '알',
    iconKey: 'Almonds_ic',
  ),
  FoodEquivalent(
    id: 'instant_coffee',
    kcalPerServing: 50,
    nameKr: '믹스커피',
    amountPerServing: 1,
    unitLabel: '잔',
    iconKey: 'Instant_Coffee_ic',
  ),
  FoodEquivalent(
    id: 'mandarin',
    kcalPerServing: 60,
    nameKr: '귤',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Mandarin_ic',
  ),
  FoodEquivalent(
    id: 'string_cheese',
    kcalPerServing: 70,
    nameKr: '스트링치즈',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'String_Cheese_ic',
  ),
  FoodEquivalent(
    id: 'boiled_egg',
    kcalPerServing: 80,
    nameKr: '삶은 계란',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Boiled_Egg_ic',
  ),
  FoodEquivalent(
    id: 'yogurt_drink',
    kcalPerServing: 90,
    nameKr: '요구르트',
    amountPerServing: 1,
    unitLabel: '병',
    iconKey: 'Yogurt_Drink_ic',
  ),
  FoodEquivalent(
    id: 'banana',
    kcalPerServing: 100,
    nameKr: '바나나',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Banana_ic',
  ),
  FoodEquivalent(
    id: 'slice_of_bread',
    kcalPerServing: 120,
    nameKr: '식빵',
    amountPerServing: 1,
    unitLabel: '장',
    iconKey: 'Slice_of_Bread_ic',
  ),
  FoodEquivalent(
    id: 'coke',
    kcalPerServing: 140,
    nameKr: '콜라',
    amountPerServing: 250,
    unitLabel: 'ml',
    iconKey: 'Coke_ic',
  ),
  FoodEquivalent(
    id: 'macaron',
    kcalPerServing: 150,
    nameKr: '마카롱',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Macaron_ic',
  ),
  FoodEquivalent(
    id: 'potato_chips',
    kcalPerServing: 160,
    nameKr: '감자칩',
    amountPerServing: 10,
    unitLabel: '개',
    iconKey: 'Potato_Chips_ic',
  ),
  FoodEquivalent(
    id: 'choco_pie',
    kcalPerServing: 170,
    nameKr: '초코파이',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Choco_Pie_ic',
  ),
  FoodEquivalent(
    id: 'sweet_potato',
    kcalPerServing: 190,
    nameKr: '고구마',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Sweet_Potato_ic',
  ),
  FoodEquivalent(
    id: 'tuna_mayo_triangle',
    kcalPerServing: 200,
    nameKr: '참치마요 삼각김밥',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Tuna_Mayo_ic',
  ),
  FoodEquivalent(
    id: 'cheese_pizza',
    kcalPerServing: 250,
    nameKr: '치즈 피자',
    amountPerServing: 1,
    unitLabel: '판',
    iconKey: 'Cheese_Pizza_ic',
  ),
  FoodEquivalent(
    id: 'steamed_rice',
    kcalPerServing: 300,
    nameKr: '쌀밥',
    amountPerServing: 210,
    unitLabel: 'g',
    iconKey: 'Steamed_Rice_ic',
  ),
  FoodEquivalent(
    id: 'fish_shaped_pastry',
    kcalPerServing: 350,
    nameKr: '붕어빵',
    amountPerServing: 3,
    unitLabel: '개',
    iconKey: 'Fish-shaped_Pastry_ic',
  ),
  FoodEquivalent(
    id: 'cheeseburger',
    kcalPerServing: 400,
    nameKr: '치즈버거',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Cheeseburger_ic',
  ),
  FoodEquivalent(
    id: 'ham_cheese_sandwich',
    kcalPerServing: 450,
    nameKr: '햄치즈 샌드위치',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'HamCheese_ic',
  ),
  FoodEquivalent(
    id: 'ramen',
    kcalPerServing: 500,
    nameKr: '라면',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Ramen_ic',
  ),
  FoodEquivalent(
    id: 'big_mac',
    kcalPerServing: 550,
    nameKr: '빅맥',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Big_Mac_ic',
  ),
  FoodEquivalent(
    id: 'jajangmyeon',
    kcalPerServing: 600,
    nameKr: '짜장면',
    amountPerServing: 1,
    unitLabel: '그릇',
    iconKey: 'Jajangmyeon_ic',
  ),
  FoodEquivalent(
    id: 'pork_cutlet',
    kcalPerServing: 650,
    nameKr: '돈까스',
    amountPerServing: 1,
    unitLabel: '인분',
    iconKey: 'Pork_Cutlet_ic',
  ),
  FoodEquivalent(
    id: 'jeyuk_deopbab',
    kcalPerServing: 700,
    nameKr: '제육덮밥',
    amountPerServing: 1,
    unitLabel: '그릇',
    iconKey: 'Jeyuk_Deopbab_ic',
  ),
  FoodEquivalent(
    id: 'jjamppong',
    kcalPerServing: 750,
    nameKr: '짬뽕',
    amountPerServing: 1,
    unitLabel: '그릇',
    iconKey: 'Jjamppong_ic',
  ),
  FoodEquivalent(
    id: 'samgyeopsoju',
    kcalPerServing: 800,
    nameKr: '삼겹살소주',
    amountPerServing: 1,
    unitLabel: '인분반병',
    iconKey: 'Samgyeopsoju_ic',
  ),
  FoodEquivalent(
    id: 'carbonara',
    kcalPerServing: 850,
    nameKr: '까르보나라',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Carbonara_ic',
  ),
  FoodEquivalent(
    id: 'burger_meal',
    kcalPerServing: 900,
    nameKr: '햄버거 세트',
    amountPerServing: 1,
    unitLabel: '세트',
    iconKey: 'Burger_Meal_ic',
  ),
  FoodEquivalent(
    id: 'malatang',
    kcalPerServing: 950,
    nameKr: '마라탕',
    amountPerServing: 1,
    unitLabel: '개',
    iconKey: 'Malatang_ic',
  ),
  FoodEquivalent(
    id: 'chimeak',
    kcalPerServing: 1000,
    nameKr: '치맥',
    amountPerServing: 1,
    unitLabel: '한마리1잔',
    iconKey: 'Chimeak_ic',
  ),
  FoodEquivalent(
    id: 'combination_pizza_large',
    kcalPerServing: 1500,
    nameKr: '콤비네이션 피자 (L)',
    amountPerServing: 1,
    unitLabel: '판',
    iconKey: 'Combination_Pizza_L_ic',
  ),
  FoodEquivalent(
    id: 'box_of_donuts',
    kcalPerServing: 2400,
    nameKr: '도넛 박스',
    amountPerServing: 12,
    unitLabel: '개입',
    iconKey: 'Box_of_Donuts_ic',
  ),
  FoodEquivalent(
    id: 'three_chimeaks',
    kcalPerServing: 3000,
    nameKr: '치맥',
    amountPerServing: 3,
    unitLabel: '세트',
    iconKey: 'Chimeak_ic',
  ),
  FoodEquivalent(
    id: 'big_mac_bundle',
    kcalPerServing: 3800,
    nameKr: '빅맥',
    amountPerServing: 7,
    unitLabel: '개',
    iconKey: 'Big_Mac_ic',
  ),
  FoodEquivalent(
    id: 'ten_ramens',
    kcalPerServing: 5000,
    nameKr: '라면',
    amountPerServing: 10,
    unitLabel: '봉지',
    iconKey: 'Ramen_ic',
  ),
  FoodEquivalent(
    id: 'six_jajangmyeon',
    kcalPerServing: 6000,
    nameKr: '짜장면',
    amountPerServing: 10,
    unitLabel: '그릇',
    iconKey: 'Jajangmyeon_ic',
  ),
  FoodEquivalent(
    id: 'seven_chimeaks',
    kcalPerServing: 7000,
    nameKr: '치맥',
    amountPerServing: 7,
    unitLabel: '세트',
    iconKey: 'Chimeak_ic',
  ),
  FoodEquivalent(
    id: 'twenty_cheeseburgers',
    kcalPerServing: 8000,
    nameKr: '치즈버거',
    amountPerServing: 20,
    unitLabel: '개',
    iconKey: 'Cheeseburger_ic',
  ),
  FoodEquivalent(
    id: 'ten_burger_meals',
    kcalPerServing: 9000,
    nameKr: '햄버거 세트',
    amountPerServing: 10,
    unitLabel: '세트',
    iconKey: 'Burger_Meal_ic',
  ),
  FoodEquivalent(
    id: 'twenty_ramens',
    kcalPerServing: 10000,
    nameKr: '라면',
    amountPerServing: 20,
    unitLabel: '봉지',
    iconKey: 'Ramen_ic',
  ),
];
