import '../models/payment_model.dart';
import '../services/payment_api_service.dart';

class PaymentRepository {
  final PaymentApiService apiService;

  PaymentRepository({required this.apiService});

  Future<List<PaymentModel>> getMyPayments() {
    return apiService.getMyPayments();
  }
}
