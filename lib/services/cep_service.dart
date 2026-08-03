import 'dart:convert';
import 'package:http/http.dart' as http;

class EnderecoCep {
  final String rua;
  final String bairro;
  final String cidade;
  final String estado;

  EnderecoCep({
    required this.rua,
    required this.bairro,
    required this.cidade,
    required this.estado,
  });
}

/// Busca endereco a partir do CEP usando a API publica e gratuita do
/// ViaCEP (nao precisa de chave/cadastro).
class CepService {
  Future<EnderecoCep?> buscar(String cep) async {
    final cepLimpo = cep.replaceAll(RegExp(r'\D'), '');
    if (cepLimpo.length != 8) return null;

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cepLimpo/json/');
      final resposta = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resposta.statusCode != 200) return null;

      final dados = jsonDecode(resposta.body) as Map<String, dynamic>;
      if (dados['erro'] == true) return null;

      return EnderecoCep(
        rua: dados['logradouro'] as String? ?? '',
        bairro: dados['bairro'] as String? ?? '',
        cidade: dados['localidade'] as String? ?? '',
        estado: dados['uf'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
