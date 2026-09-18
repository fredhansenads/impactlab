# Verificação da primeira versão

Verificações locais concluídas em 18/09/2026:

- Flutter 3.47.4 / Dart 3.13.3: análise estática sem problemas.
- 25 testes Flutter aprovados: regras, permissões, validações repetidas, saldo insuficiente, reserva/cancelamento, revisão, limite de participação, privacidade, recorrência, conquista e recuperação de resposta perdida.
- Navegação e renderização verificadas em 360, 390, 768 e 1440 pixels de largura. Capturas em `screenshots/`, com inspeção visual de celular e desktop.
- 28 verificações PostgreSQL 17 aprovadas, incluindo oito conexões concorrentes para validação, disputa de estoque e disputa de saldo; isolamento entre escolas; vínculos; histórico imutável; correções; provisionamento e renomeação de disciplinas.

O teste de concorrência Dart verifica o motor demonstrativo em um isolate; a prova de transações concorrentes usa conexões PostgreSQL distintas. O Auth hospedado, envio de convites/SMTP, notificações nativas e dispositivos Android/iOS não foram testados neste ambiente. Consulte o README para as configurações e limitações.

A compilação Web de demonstração foi concluída e a prévia local respondeu HTTP 200 com o título Portal Escolar. A estrela da moeda usa o ícone incluído no aplicativo; a fonte Cupertino foi acrescentada para os ícones de plataforma.

Logs completos: `flutter-analyze-results.txt`, `flutter-test-results.txt`, `backend-test-results.txt` e `web-build-results.txt`.
