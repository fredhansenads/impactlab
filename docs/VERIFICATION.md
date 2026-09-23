# Verificação da primeira versão

Verificações locais concluídas em 18/09/2026:

- Flutter 3.47.4 / Dart 3.13.3: análise estática sem problemas.
- 25 testes Flutter aprovados: regras, permissões, validações repetidas, saldo insuficiente, reserva/cancelamento, revisão, limite de participação, privacidade, recorrência, conquista e recuperação de resposta perdida.
- Navegação e renderização verificadas em 360, 390, 768 e 1440 pixels de largura. Capturas em `screenshots/`, com inspeção visual de celular e desktop.
- 28 verificações PostgreSQL 17 aprovadas, incluindo oito conexões concorrentes para validação, disputa de estoque e disputa de saldo; isolamento entre escolas; vínculos; histórico imutável; correções; provisionamento e renomeação de disciplinas.

O teste de concorrência Dart verifica o motor demonstrativo em um isolate; a prova de transações concorrentes usa conexões PostgreSQL distintas. O Auth hospedado, envio de convites/SMTP, notificações nativas e dispositivos Android/iOS não foram testados neste ambiente. Consulte o README para as configurações e limitações.

A compilação Web de demonstração foi concluída e a prévia local respondeu HTTP 200 com o título Portal Escolar. A estrela da moeda usa o ícone incluído no aplicativo; a fonte Cupertino foi acrescentada para os ícones de plataforma.

Logs completos: `flutter-analyze-results.txt`, `flutter-test-results.txt`, `backend-test-results.txt` e `web-build-results.txt`.

## Identidade ImpactLab — 23/09/2026

- Logo fornecido preservado byte a byte no asset original; ícones de Android, iOS e Web gerados proporcionalmente pelo script `tool/generate_brand_assets.dart`.
- Paleta azul-marinho, azul e ciano aplicada à interface, mantendo dourado para Star Coins e fundos claros para leitura.
- Análise estática sem problemas e 25 testes Flutter aprovados após a adaptação, incluindo navegação dos cinco perfis em 360, 768 e 1440 pixels.
- Capturas atualizadas em 390 e 1440 pixels, incluindo a tela de acesso. Inspeção visual do início, carteira e acesso; rótulos da navegação ajustados para telas pequenas.
- Capturas aguardam o carregamento do logo e substituem os arquivos por renomeação para evitar bloqueios de imagens abertas no Windows.
- Compilação Web release concluída; prévia restrita a localhost respondeu HTTP 200 com o título ImpactLab. Nenhuma implantação pública realizada.
- Logs desta alteração: `branding-analyze-results.txt`, `branding-test-results.txt` e `branding-web-build-results.txt`. Os testes PostgreSQL acima pertencem à primeira versão; não houve alteração no backend nesta adaptação visual.
- Android e iOS continuam sem validação em dispositivo ou simulador neste ambiente.

## Preparação móvel gratuita — 23/09/2026

- Caminho escolhido: APK de demonstração para Android e prévia Web no Safari do iPhone. O usuário informou não ter acesso a Mac.
- `flutter analyze`: sem problemas. `flutter test`: 26 testes aprovados, incluindo o roteiro compartilhado de navegação, cinco perfis e envio de texto em tela de 390 × 844.
- Geração de assets: concluída. XML dos recursos Android e storyboard iOS: leitura sintática concluída sem erros. Isso não equivale à renderização do splash em aparelho.
- Assinatura Android de distribuição separada da chave debug, com exigência de configuração local para release. Gradle limitado a 2 GB de heap e dois workers para computadores com pouca memória.
- A primeira tentativa local de APK foi interrompida por nós após pressão de memória; a geração do pacote foi encaminhada ao workflow `Mobile demo` no GitHub. Ferramentas cmdline do Android SDK ainda precisam de configuração neste PC para `flutter doctor` ficar completo.
- A verificação PostgreSQL no GitHub passou após ajustar a espera de inicialização do contêiner: o teste agora aguarda TCP loopback do servidor final, evitando o servidor temporário de inicialização.
- `integration_test/mobile_smoke_test.dart` preparado para dispositivo/simulador: interface e registro do plugin de notificações sem solicitar permissão. Ainda não executado nativamente nesta etapa.
- Simulador iOS fica opcional e desativado por padrão no workflow. Nenhum IPA assinado, teste em iPhone instalado, conta paga ou publicação de loja foi realizado.
- Guia de uso: `MOBILE.md`. Logs locais: `mobile-analyze-results.txt`, `mobile-test-results.txt`.
- APK Android compilado com sucesso no GitHub em 23/09/2026: [Mobile demo, execução 35893538128](https://github.com/fredhansenads/impactlab/actions/runs/35893538128), commit `319f9d68fe9caf5f0bea91df11412290a5609e0c`.
- Artefato `ImpactLab-Android-demo`, ID `10766106094`: ZIP e APK baixados e conferidos por SHA-256. APK: `131309a59b83944d7a8d44af84d7a95194b11a0f95e30b52170559723436bf9a`, 161.403.580 bytes. Cópia local em `dist/android/app-debug.apk` (fora do Git).
- `apksigner verify`: assinatura debug válida (APK Signature Scheme v2). `aapt`: ImpactLab 0.1.0+1, pacote `br.edu.portal.portal_escolar`, mínimo SDK 24, target SDK 36, arquiteturas armeabi-v7a/arm64-v8a/x86_64. MainActivity confirmada no DEX. Registro em `mobile-apk-verification.txt`.
- APK disponibilizado temporariamente em `build/web/downloads/ImpactLab-demo.apk`, servido apenas pela rede local já utilizada na prévia. HTTP HEAD retornou 200 e o tamanho esperado. Uma nova compilação Web pode remover essa cópia; o pacote original permanece em dist.
- [Verify, execução 35893537837](https://github.com/fredhansenads/impactlab/actions/runs/35893537837): Flutter e PostgreSQL concluídos com sucesso. O APK ainda não foi executado em aparelho Android; iOS nativo permanece não executado.
