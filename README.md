# Awake — App do Ministério

App mobile (Flutter) para gestão do ministério Awake: calendário, escalas de
voluntariado com check-in por QR Code, metas/troféus e treinamentos.

**Este pacote entrega o MVP:** Autenticação, Calendário e Voluntariado
(inscrição em escalas + check-in via QR Code). Os módulos de Metas/Troféus e
Treinamentos ficam para a próxima fase (o modelo de dados já foi desenhado
em `modelo-tecnico-app-awake.md`, é só continuar a partir daqui).

A interface já usa a identidade visual oficial do Awake (cores, logo e ícone
de chama extraídos de `ID_VISUAL_-_AWAKE.pdf`) — ver seção "Identidade
Visual" abaixo para detalhes e pendências.

---

## Stack

- **Flutter** (Dart) — cross-platform Android/iOS
- **Supabase** — Auth, banco de dados (Postgres), Row Level Security
- **Riverpod** — gerenciamento de estado
- **go_router** — navegação
- **OneSignal** — push notifications
- **qr_flutter** / **mobile_scanner** — geração e leitura de QR Code

---

## 1. Configurar o Supabase

1. Crie um projeto em [supabase.com](https://supabase.com)
2. No painel, vá em **SQL Editor** → **New query**
3. Cole o conteúdo de `supabase/schema.sql` e rode
   - Isso cria as tabelas, os tipos, as funções (`cancel_signup`,
     `check_in_member`, `solicitar_papel_lider`), as policies de RLS e
     algumas áreas de serviço de exemplo (edite a lista no final do
     arquivo para as áreas reais do seu ministério)
   - **Importante:** no final do arquivo tem uma linha
     `select public.set_leader_code('MUDE-ESTE-CODIGO');` — troque
     `'MUDE-ESTE-CODIGO'` pelo código real que você vai distribuir para
     os líderes antes de rodar (ou rode de novo depois, a qualquer
     momento, pra trocar o código)
4. Vá em **Authentication → Providers** e confirme que **Email** está
   habilitado (é o método usado no MVP)
5. Vá em **Settings → API** e copie:
   - `Project URL`
   - `anon public key`

## 2. Configurar o OneSignal (push notifications)

1. Crie uma conta e um app em [onesignal.com](https://onesignal.com)
2. Configure a plataforma Android (Firebase Server Key/Sender ID) e iOS
   (certificado APNs) seguindo o próprio wizard do OneSignal
3. Copie o **OneSignal App ID**

> Push funciona por integração de infraestrutura de notificação (Android
> exige Firebase Cloud Messaging por baixo, mesmo usando OneSignal por
> cima) — o OneSignal cuida dessa parte, você só precisa seguir o wizard
> deles.

## 3. Gerar os arquivos de plataforma (Android/iOS) — passo obrigatório

Este pacote traz o código Dart (`lib/`) e a configuração (`pubspec.yaml`),
mas **não inclui as pastas `android/`, `ios/` e `web/`** — elas são geradas
pelo próprio Flutter e variam conforme a versão instalada na sua máquina.
Sem isso, o projeto não builda.

Rode uma vez, na raiz do projeto (não sobrescreve `lib/` nem `pubspec.yaml`):

```bash
flutter create .
```

Depois disso o projeto fica completo e pronto para rodar/buildar. Faça isso
**antes** do primeiro `git push` — as pastas geradas precisam estar no
repositório para o GitHub Actions conseguir compilar o APK (ver seção
"Publicar no GitHub" mais abaixo).

## 4. Rodar o projeto localmente

```bash
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://seuprojeto.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sua-anon-key \
  --dart-define=ONESIGNAL_APP_ID=seu-onesignal-app-id
```

Alternativa: edite diretamente os valores padrão em `lib/core/env.dart`
(mais simples para testar, mas evite commitar chaves reais no Git dessa
forma — prefira sempre `--dart-define` ou um `.env` fora do controle de
versão).

## 5. Primeiro acesso

- Membros se cadastram normalmente pelo app
- Para virar **líder**, a pessoa escolhe "Líder" na tela de cadastro e
  informa o código de líder — configure esse código no Supabase antes de
  liberar o app (ver passo final de `supabase/schema.sql`: `set_leader_code`)
- Para virar **admin** (só você), no Supabase vá em **Table Editor →
  profiles**, encontre seu usuário e edite o campo `papel` para `admin`
  manualmente (não existe tela de administração ainda)

---

## Publicar no GitHub (landing page + APK para baixar)

Este projeto já vem com tudo pronto para: (1) uma página simples no GitHub
Pages com um botão "Baixar APK", e (2) uma Action que compila o APK e
publica automaticamente toda vez que você lançar uma versão.

### 1. Criar o repositório e subir o código

```bash
git init
git add .
git commit -m "Primeira versao do app Awake"
git branch -M main
git remote add origin https://github.com/SEU-USUARIO/SEU-REPOSITORIO.git
git push -u origin main
```

### 2. Cadastrar os segredos do projeto no GitHub

No repositório: **Settings → Secrets and variables → Actions → New
repository secret**. Crie 3 segredos (mesmos valores que você usa no
`--dart-define` local):

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `ONESIGNAL_APP_ID`

Isso é necessário porque o build do APK acontece no GitHub, não na sua
máquina — sem esses segredos, o app compilado não vai conseguir falar com
o Supabase.

### 3. Ativar o GitHub Pages

**Settings → Pages → Source:** selecione "Deploy from a branch" → branch
`main` → pasta `/docs`. Salve. Em alguns minutos, o link
`https://SEU-USUARIO.github.io/SEU-REPOSITORIO/` estará no ar mostrando a
página de download (`docs/index.html`) — o botão de baixar o APK já é
montado automaticamente a partir da própria URL, sem precisar editar nada.

### 4. Gerar e publicar o APK

Toda vez que quiser lançar uma nova versão, crie uma tag e envie:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Isso dispara o workflow `.github/workflows/build-release.yml`, que builda
o APK e o publica automaticamente como um "Release" do GitHub — o botão
"Baixar APK" da landing page sempre aponta para o release mais recente. Dá
pra acompanhar o progresso na aba **Actions** do repositório (leva alguns
minutos).

> **Nota sobre assinatura do APK:** por padrão, este workflow gera um APK
> assinado com a chave de debug do Flutter — funciona perfeitamente para
> instalar direto no celular (sideload, que é o seu caso aqui), mas **não
> é aceito pela Play Store**. Se um dia quiser publicar na Play Store,
> aí sim vale configurar uma chave de assinatura de release própria.

---

## Estrutura do projeto

```
lib/
  core/           # env, tema, router
  models/         # classes de dados (Profile, Event, Shift, Signup...)
  services/       # chamadas ao Supabase (uma classe por domínio)
  providers/      # Riverpod (estado + acesso aos services)
  screens/
    auth/         # login, cadastro
    home/         # shell com navegação por abas
    calendar/     # listagem, detalhe e criação de eventos
    volunteering/ # escalas, QR code pessoal, check-in do líder
    profile/      # dados do usuário logado, logout
assets/
  images/         # logo e ícone de chama (extraídos do PDF de identidade)
supabase/
  schema.sql      # schema completo: tabelas, RLS, funções de negócio
```

---

## Identidade Visual

Já aplicada em `lib/core/theme/app_theme.dart`:

- **Cores:** navy `#0C192E` (primária), amarelo `#FFD21F` (destaque/CTA),
  off-white `#F7F7F6` (fundo), azul-acinzentado `#D9DFE6` (superfícies)
- **Logo:** `assets/images/awake_logo_white.png` (fundo escuro) e
  `awake_logo_black.png` (fundo claro) — extraídos em alta resolução
  diretamente do PDF de identidade
- **Ícone de chama:** `awake_flame_white.png` e `awake_flame_navy.png`
- **Fonte:** a identidade pede "Canva Sans", que é proprietária da Canva e
  não pode ser embutida no app sem licença própria. Por enquanto o tema usa
  **Plus Jakarta Sans** (Google Fonts, open-source) como substituta visual
  próxima — troque em `app_theme.dart` (`_bodyFont`) se conseguir os
  arquivos oficiais licenciados da Canva Sans
- **Pendência:** as imagens do logo/ícone foram extraídas/rasterizadas do
  PDF (boa qualidade para uso em tela, mas não são vetor). Se depois você
  tiver o arquivo original (SVG/AI/Figma), vale substituir os PNGs em
  `assets/images/` pelos vetoriais

---

## Pontos de atenção antes de ir para produção

1. **LGPD / menores de idade.** O cadastro hoje só mostra um aviso e um
   checkbox de aceite de termos. Como parte dos membros são menores de
   idade, vale evoluir isso para um fluxo real de consentimento do
   responsável antes do lançamento (ver comentário `TODO` em
   `signup_screen.dart`).
2. **Regras de RLS.** As políticas de segurança em `schema.sql` foram
   escritas com cuidado, mas **teste bastante** com usuários `membro` e
   `lider` reais antes de lançar — é fácil deixar uma brecha sem perceber.
3. **Índice/paginação.** As listagens (eventos, escalas) hoje trazem tudo
   de uma vez. Com 250 membros e uso normal isso não deve ser problema,
   mas se o histórico crescer muito, vale paginar.
4. **Nomes dos ícones dos troféus** (módulo futuro) ainda são só sugestões
   textuais — ver `modelo-tecnico-app-awake.md`.

## Próximos passos (fora deste MVP)

- Módulo de Metas e Troféus (cálculo mensal automático + galeria de troféus)
- Módulo de Treinamentos (infográficos/vídeos por área, player embutido)
- Tela de administração de usuários (promover líder/admin sem mexer direto
  no banco)
- Integração com WhatsApp (fase futura, conforme já definido nos
  requisitos)
