/// Converte um DateTime UTC (ex: um `criado_em` de timestamptz vindo
/// direto do Supabase) pro horario de Brasilia, com um deslocamento
/// FIXO de -3h -- Brasil nao tem mais horario de verao desde 2019 (ver
/// tool/robo_teste/bin/robo.dart, mesma logica: `_agoraBrasilia()`).
///
/// Preferido a `DateTime.toLocal()`: `.toLocal()` depende do fuso
/// horario CONFIGURADO NO APARELHO de quem esta vendo -- se o celular
/// de alguem estiver com o fuso errado (acontece, mesmo com "automatico"
/// ligado), a data mostrada sai errada mesmo com o dado certo no banco.
/// Como o app so' serve gente no fuso de Brasilia, fixar o deslocamento
/// aqui evita esse problema por completo, em vez de confiar no aparelho.
DateTime paraBrasilia(DateTime dataUtc) {
  return dataUtc.toUtc().subtract(const Duration(hours: 3));
}

/// "Agora", no mesmo esquema -- pra comparar com um DateTime que veio
/// de [paraBrasilia] (ex: "quantos visitantes essa semana/mes") sem
/// depender do fuso do aparelho pra nenhum dos dois lados da conta.
DateTime agoraBrasilia() => paraBrasilia(DateTime.now());
