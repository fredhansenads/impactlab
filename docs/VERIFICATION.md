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
