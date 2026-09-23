# ImpactLab — primeira versão funcional

Aplicativo Flutter/Dart para Android e iOS, com prévia Web. **ImpactLab é o nome do aplicativo; Star Coin é o nome da moeda.** Interface em português do Brasil, dados fictícios na demonstração e nenhuma publicação externa realizada.

<p align="center"><img src="assets/branding/impactlab-logo.jpeg" alt="Logo ImpactLab" width="240" /></p>

## Executar a demonstração

Requer Flutter 3.47.4 (versão verificada), Dart 3.13.3 e um navegador ou dispositivo configurado.

```powershell
flutter pub get
flutter run -d chrome --dart-define=DEMO_MODE=true
# Android conectado/emulador configurado:
flutter run -d <identificador-do-dispositivo> --dart-define=DEMO_MODE=true
# iOS: executar o equivalente em um Mac com Xcode e simulador/dispositivo.
```

Neste computador, um SDK local foi obtido em `.tools/flutter` (ignorado pelo Git). Se Flutter não estiver no PATH, substitua `flutter` por `.\.tools\flutter\bin\flutter.bat`.

A faixa azul de demonstração permite alternar os cinco perfis **apenas na demonstração**. As alterações ficam em memória durante a sessão e são descartadas ao reiniciar. Não são contas reais, não há envio de e-mails e o saldo inicial fictício de Lia é 40 Star Coins.

### Roteiro integrado

1. Alterne para **Professor** e use **Publicar atividade**. Escolha a turma 7º A, Ciências para atividade acadêmica, critérios observáveis, prazo e moedas. A pontuação sugerida acompanha o tipo e pode ser alterada.
2. Como **Aluno**, encontre a publicação em Agenda ou Missões, abra e envie texto. O saldo ainda não muda.
3. Como **Professor**, abra a entrega e valide ou solicite ajustes. A seleção de entregas permite validação em lote.
4. Volte a **Aluno** e consulte Carteira: o crédito registra atividade, data e autor. Reservar o adesivo custa 30 moedas.
5. Em Recompensas, copie o código do resgate. Como **Equipe de entrega**, use **Conferir código** e confirme a entrega do item.
6. **Responsável** acompanha Lia, as avaliações, carteira e recompensas. Pode confirmar a missão “Uma história para compartilhar”, explicitamente atribuída à família. Não acessa lembretes pessoais.
7. **Coordenação** administra regras, recompensas, estoque, cadastros, vínculos e correções justificadas. O botão de pessoa adiciona contas fictícias no demo; contas adicionais podem ser matriculadas e vinculadas, mas a alternância rápida mantém as cinco personas iniciais.

## O que está implementado

- Início com próximos prazos, carteira e meta da turma; agenda por dia, semana e próximos compromissos, com filtros de disciplina e situação.
- Atividades acadêmicas, boas práticas e missões coletivas: início, prazo, critérios, categoria, turma, validador, frequência, limite e moedas. A API também aceita lista de participantes; o formulário desta versão publica para a turma inteira.
- Entrega textual, ajustes, revisão, validação individual/em lote, prorrogação, adaptação dos critérios e cancelamento. Atraso separado do estado e calculado pela data da entrega.
- Agenda pessoal privada, sem moedas. Compromissos oficiais e particulares são diferenciados.
- Carteira com disponível, reservado, total bruto concedido e histórico imutável. Correções criam estornos referenciados e não apagam conquistas.
- Catálogo com ícones ilustrativos, preço, estoque, período, limite individual e retirada. Reserva transacional, código de uso único, entrega e cancelamento consistente. Imagens externas opcionais não são necessárias; upload de imagens não integra esta versão.
- Conquista Parceiro da Turma após cinco participações de colaboração que contribuam para metas. Progresso coletivo sem debitar saldo, sem ranking ou sequências de presença.
- Interfaces específicas dos cinco perfis; recuperação de acesso e alteração de senha no modo real; convite de usuários via Edge Function fornecida.
- Avisos de validação e resgate dentro do aplicativo. Lembretes locais de prazo em Android/iOS, com permissão pedida no botão de ativação da área de avisos.
- Carregamento, estado vazio, mensagens de erro, atualização manual, confirmações e bloqueio de ações duplicadas durante processamento. Comandos reais não são enfileirados offline.

Não há conversão de moedas em notas, compras com dinheiro, transferências, expiração, blockchain, anúncios, chat, localização ou fotos de alunos.

## Backend escolhido: Supabase

Firebase foi considerado: Firestore fornece transações e autenticação adequada a aplicativos móveis. Escolhemos **Supabase Auth + PostgreSQL** pelas relações entre escola, turma e família, funções transacionais e auditoria. A autorização fica no servidor. Documentação oficial: [Flutter/Supabase](https://supabase.com/docs/guides/getting-started/quickstarts/flutter), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [funções PostgreSQL](https://supabase.com/docs/guides/database/functions) e [transações Firestore](https://firebase.google.com/docs/firestore/manage-data/transactions).

O backend não foi implantado. O aplicativo real já possui adaptador RPC e autenticação; a demonstração usa um adaptador separado sobre o motor de regras Dart.

### Configuração real

1. Crie um projeto Supabase administrado pela escola. Aplique, em ordem, `supabase/migrations/001_school.sql` e `002_provisioning.sql`. **Não aplique `supabase/tests/auth_stub.sql`: ele simula Auth exclusivamente nos testes locais.**
2. Crie a primeira conta de coordenação no Supabase Auth. Execute `supabase/bootstrap.sql` via `psql`, informando `coordinator_id` (UUID dessa conta) e `school_name` como variáveis. O script cria uma escola nova e as regras iniciais; não serve para repetir a inicialização de uma escola existente. Alternativamente, execute os mesmos inserts no SQL Editor com os identificadores reais.
3. Configure Auth para contas administradas pela escola, política de senha, SMTP e URLs de redirecionamento permitidas. O esquema nativo `portal-escolar://login-callback` está nos projetos Android/iOS; valide o fluxo de links em aparelhos reais. Desative autoinscrição pública: perfis nunca são inferidos de metadados enviados pelo usuário.
4. Para cadastrar usuários pela interface, configure e implante **somente após autorização** a Edge Function `invite-user`. `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` ficam no ambiente da função. Defina `INVITE_REDIRECT_URL` na função e permita essa URL no Auth. A service-role jamais é entregue ao aplicativo. A função verifica sessão e perfil, envia o convite e provisiona o usuário na escola do coordenador. Se o provisionamento falhar, tenta remover apenas a conta criada naquele pedido.
5. O usuário aceita o convite, abre o app e usa Perfil → Definir ou alterar senha. A recuperação por e-mail fica na tela de acesso. Configure `AUTH_REDIRECT_URL` para o mesmo callback ou para uma página Web de ativação administrada pela escola.
6. Cadastre turmas, disciplinas, professores, alunos, atribuições e vínculos. Novos alunos começam com saldo zero. Cadastre recompensas e locais antes de permitir resgates. Metas coletivas usam registros `goals` da turma com `name`, `description` e `target`; a primeira versão tem visualização e contribuições automáticas, sem editor de metas na interface.
7. Compile com variáveis locais, por exemplo em `config.local.json` (adicione ao ignore de sua distribuição):

```json
{
  "DEMO_MODE": "false",
  "SUPABASE_URL": "https://SEU-PROJETO.supabase.co",
  "SUPABASE_ANON_KEY": "CHAVE-PUBLICA-DO-PROJETO",
  "AUTH_REDIRECT_URL": "portal-escolar://login-callback"
}
```

```powershell
flutter run --dart-define-from-file=config.local.json
```

A chave pública do Supabase identifica o projeto; a proteção é feita por sessão e autorização no servidor. Não coloque chaves de serviço, senhas ou tokens de sessão no código, no controle de versão ou nos argumentos de build. Use um arquivo local protegido para configurações. Nunca use o arquivo ilustrativo como credencial real.

## Estrutura

- `lib/features/`: interfaces de atividades, agenda, carteira, recompensas, escola e autenticação.
- `lib/core/`: contratos de dados, estado de aplicação, erros, componentes e formulários.
- `lib/domain/school_engine.dart`: regras da demonstração, com rollback e controle de permissões.
- `lib/data/`: dados fictícios e adaptadores em memória/Supabase.
- `supabase/migrations/`: autorização e transações reais. `supabase/functions/`: convite de contas.
- `test/`: regras, fluxo por interface, navegação e renderização.
- `tool/test_backend.py`: testes reais PostgreSQL, incluindo múltiplas conexões simultâneas.
- `docs/ARCHITECTURE.md`: dados, garantias, fronteiras e decisões futuras.

## Verificação

```powershell
flutter analyze
flutter test
flutter test --dart-define=CAPTURE_SCREENSHOTS=true
flutter build web --release --dart-define=DEMO_MODE=true
```

Os testes de captura usam fontes com suas licenças em `test/fonts`. As capturas ficam em `docs/screenshots` e não equivalem a testes em aparelhos Android ou iOS.

Para testar o backend sem Supabase externo, instale Docker e Python 3:

```powershell
docker run --detach --name impactlab-postgres-test --network none --env POSTGRES_HOST_AUTH_METHOD=trust postgres:17-alpine
python tool/test_backend.py
# Ao terminar:
docker stop impactlab-postgres-test
```

O contêiner não expõe portas nem tem rede. A autenticação sem senha é exclusiva desse banco descartável isolado, não uma configuração de produção. Cada execução cria um banco `portal_test_<timestamp>` e o mantém para inspeção. O runner testa a migração, o escopo equivalente ao JWT e as permissões SQL; não testa o serviço de e-mail ou o Supabase Auth hospedado.

Resumo dos 25 testes Flutter e 28 verificações PostgreSQL em `docs/VERIFICATION.md`. Resultados detalhados em `docs/flutter-analyze-results.txt`, `docs/flutter-test-results.txt`, `docs/backend-test-results.txt` e `docs/web-build-results.txt`.

## Limites e próximos passos para uma escola real

- Validado localmente: análise estática, testes Flutter, renderização em larguras de 360, 390, 768 e 1440 pixels, compilação Web e testes transacionais no PostgreSQL 17.
- **Android/iOS não foram testados em aparelho ou simulador.** Android está sem cmdline-tools e validação de licenças; iOS exige Mac/Xcode. Assinaturas de distribuição e publicação não foram configuradas. O projeto Android mantém assinatura de depuração apenas para desenvolvimento.
- Login, convites, recuperação, SMTP e notificações nativas precisam de teste ponta a ponta com as credenciais e os dispositivos da escola. A Edge Function foi fornecida, mas não executada contra Auth real.
- Lembretes locais: opt-in contextual, próximos 40 prazos, 24 horas antes, entrega aproximada no Android. Reative na nova sessão para reprogramar com os dados atuais; alterações feitas enquanto o app permanece fechado não atualizam a agenda local. Desativar cancela os lembretes pendentes.
- Push de validação/resgate com o aplicativo fechado requer FCM/APNs e um consumidor autorizado das notificações do banco; não está ativo. Os avisos internos funcionam ao atualizar os dados.
- Esta versão tem relatórios resumidos na coordenação; exportação, paginação de grandes históricos, administração avançada do ciclo de vida de contas e editor de metas são extensões identificadas.
- Antes do uso real: revisar as regras da escola, acessibilidade com leitores de tela, retenção de dados, backup/restauração, monitoramento e políticas de acesso. Não foi feita avaliação jurídica nem afirmação de conformidade legal.

## Prévia local da compilação Web

Depois de `flutter build web`, execute `python tool/serve_preview.py`. O script escolhe uma porta disponível e mostra o endereço local. Ele serve apenas a pasta `build/web` em `127.0.0.1`, sem publicação externa. Use Ctrl+C para encerrar.

## Identidade visual

O aplicativo usa azul-marinho (`#04122D`), azul (`#0756B5`) e ciano (`#27D8F4`), inspirados no logo. Fundos claros (`#F4F7FC`) preservam a leitura; o dourado identifica as Star Coins. A identidade está aplicada ao acesso, cabeçalho, navegação, agenda, missões, carteira e recompensas.

Logo original fornecido pelo responsável pelo projeto em 23/09/2026: `assets/branding/impactlab-logo.jpeg`. A imagem é preservada, sem redesenho; os ícones de Android, iOS e Web são renderizados proporcionalmente, com margem para evitar cortes. Para regenerar esses arquivos: `flutter test tool/generate_brand_assets.dart`. Os nomes técnicos do pacote Dart e dos identificadores nativos permanecem compatíveis com a configuração existente.
