import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/network/api_endpoints.dart';
import 'package:starq_app/core/utils/json_helpers.dart';
import 'package:starq_app/features/rewards/domain/rewards_model.dart';

class RewardsRepository {
  final ApiClient _api = ApiClient();

  Future<RewardAccount> load() async {
    final res = await _api.get(ApiEndpoints.rewards);
    return RewardAccount.fromJson(asJsonMap(asJsonMap(res.data)['data']));
  }

  Future<void> redeem(String rewardId) async {
    await _api.post(ApiEndpoints.redeemReward, data: {'reward_id': rewardId});
  }
}
