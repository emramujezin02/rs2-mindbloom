import '../../../../core/network/api_client.dart';
import '../models/payment_model.dart';

class PaymentApiService {
  final ApiClient apiClient;

  PaymentApiService({required this.apiClient});

  Future<List<PaymentModel>> getMyPayments() async {
    final response = await apiClient.get('/Payments/mine');

    return (response as List).map((e) => PaymentModel.fromJson(e)).toList();
  }
}
