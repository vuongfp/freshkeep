import 'pantry_service.dart';

class FoodExpiryDefaultsService {
  final PantryService _pantryService = PantryService();

  Future<int> getExpiryDays(String foodType) async {
    final type = foodType.toLowerCase();
    return _pantryService.getExpiryDefault(type);
  }

  Future<void> setExpiryDays(String foodType, int days) async {
    final type = foodType.toLowerCase();
    await _pantryService.setExpiryDefault(type, days);
  }
}