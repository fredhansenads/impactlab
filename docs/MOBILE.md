# Testes móveis gratuitos

O projeto continua em Flutter. Expo Go executa projetos Expo/React Native e não é necessário para gerar nosso APK.

## Android: APK de demonstração

Com Flutter 3.47.4, Java 17 ou superior e Android SDK configurados:

```sh
flutter pub get
flutter build apk --debug --dart-define=DEMO_MODE=true
```

Saída: `build/app/outputs/flutter-apk/app-debug.apk`. É uma compilação de teste assinada com chave de depuração, sem conta de loja e sem publicação. Transfira o APK para o Android e autorize a instalação para o aplicativo usado para abri-lo. A demonstração contém apenas dados fictícios, permite alternar perfis e perde alterações ao encerrar o processo. Não use esse pacote com dados reais da escola.

No GitHub, o workflow **Mobile demo** gera o mesmo APK e um SHA-256 no artefato **ImpactLab-Android-demo**. A geração ocorre em mudanças móveis na branch main e pode ser iniciada em Actions → Mobile demo → Run workflow. A retenção do artefato é de 7 dias; é necessário entrar no GitHub para baixá-lo. Isso não publica nas lojas. A chave de depuração pode variar entre máquinas de compilação; se houver conflito de assinatura ao atualizar um teste, remova a instalação de teste anterior (isso apaga seus dados locais) ou compile com a mesma chave.

Se o SDK estiver incompleto, use Android Studio → SDK Manager → SDK Tools para instalar **Android SDK Command-line Tools (latest)**. Depois execute `flutter doctor --android-licenses`, leia os termos apresentados, aceite se concordar e confira `flutter doctor -v`. O Gradle poderá precisar baixar SDK/NDK e dependências na primeira compilação.

## iPhone: Safari por enquanto

Sem acesso a um Mac, use a prévia Web já fornecida na mesma rede Wi-Fi. O computador precisa permanecer ligado e o endereço local pode mudar. O servidor serve somente `build/web`, sem implantação pública. Essa modalidade testa a interface e os fluxos demonstrativos, mas não valida instalação iOS, permissões ou notificações nativas.

## iOS nativo quando houver um Mac

Requer Mac, Xcode configurado, SDK iOS e Flutter. O projeto usa iOS 15 ou superior e Swift Package Manager; o Flutter gera os arquivos efêmeros necessários. Se algum plugin exigir CocoaPods, instale-o conforme o diagnóstico do Flutter.

```sh
flutter pub get
flutter doctor -v
open ios/Runner.xcworkspace
```

No Xcode, selecione Runner → Signing & Capabilities, habilite assinatura automática e escolha sua **Personal Team**. Conecte o iPhone, confie no computador e ative o Modo de Desenvolvedor quando solicitado. Se a Apple exigir um identificador exclusivo, configure um Bundle Identifier disponível para sua conta antes da primeira instalação. Depois execute:

```sh
flutter devices
flutter run -d IDENTIFICADOR_DO_IPHONE --dart-define=DEMO_MODE=true
```

Uma conta Apple pessoal gratuita permite teste no próprio aparelho, com assinatura de 7 dias; é necessário recompilar/reinstalar após expirar. A conta e eventuais confirmações ficam no Xcode, nunca no repositório. TestFlight e App Store não fazem parte do caminho gratuito escolhido.

O workflow Mobile demo tem uma opção manual `ios_simulator`. Ela compila e testa em um simulador de iPhone no macOS, sem credenciais de distribuição. Está desativada por padrão e não produz um aplicativo instalável no iPhone físico.

## Testes

```sh
flutter analyze
flutter test
flutter test integration_test/mobile_smoke_test.dart -d IDENTIFICADOR_DO_DISPOSITIVO --dart-define=DEMO_MODE=true
```

O roteiro compartilhado testa navegação, cinco perfis e envio de texto em tela pequena. A versão nativa verifica também o registro do plugin de notificações sem pedir permissão. Execute em instalação de teste nova para que a lista de notificações pendentes esteja vazia. O teste no host não comprova execução Android/iOS.

No aparelho, confira ainda teclado, retorno do botão voltar, rotação, fontes ampliadas, leitor de tela, abertura do logo e permissão de lembretes. Teste validação de uma entrega, crédito único, reserva, cancelamento e retirada de recompensa. Os testes financeiros em memória e PostgreSQL continuam separados dos testes de dispositivo.

## Distribuição futura

A assinatura de release Android não usa mais a chave de debug como fallback. Copie `android/key.properties.example` para `android/key.properties` e preencha localmente com uma chave administrada pela escola. `storeFile` é absoluto ou relativo à pasta android. O arquivo e as chaves ficam fora do Git. Sem os dados completos, a tarefa `preReleaseBuild` interrompe a compilação de distribuição.

Para uso real, configure o backend conforme o README, aumente a versão em `pubspec.yaml`, compile com `DEMO_MODE=false` e a configuração local do Supabase. Não distribua a demonstração como versão escolar de produção. Os identificadores existentes foram preservados: Android `br.edu.portal.portal_escolar`, iOS `br.edu.portal.portalEscolar`; callback `portal-escolar://login-callback`.

Nenhuma conta paga, certificado de distribuição, publicação ou assinatura de serviço foi criada.

Fontes: [Flutter Android](https://docs.flutter.dev/deployment/android), [Flutter iOS](https://docs.flutter.dev/platform-integration/ios/setup), [conta Apple gratuita e limites](https://developer.apple.com/help/account/basics/about-your-developer-account).
