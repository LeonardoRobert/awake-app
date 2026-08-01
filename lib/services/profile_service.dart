import '../models/profile_model.dart';
import 'supabase_service.dart';

class ProfileService {
  final _client = SupabaseService.client;

  Future<ProfileModel> fetchById(String id) async {
    final data = await _client.from('profiles').select().eq('id', id).single();
    return ProfileModel.fromMap(data);
  }

  Future<List<ProfileModel>> listAll() async {
    final data = await _client.from('profiles').select().order('nome');
    return (data as List)
        .map((e) => ProfileModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
