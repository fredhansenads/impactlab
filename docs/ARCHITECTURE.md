# Arquitetura e decisões

## Persistência e autorização

`schools` representa a escola e `profiles` liga o UUID do Supabase Auth a uma única escola e papel. Não há seleção de papel no modo real. A coordenação inicial é criada administrativamente; convites seguintes passam pela Edge Function autenticada e por `provision_school_user`, executável apenas pelo serviço do servidor.

`school_records` guarda entidades discriminadas por `kind` com dados JSONB, tenant obrigatório, chave única, data e índices especializados. A opção reduz o mapeamento entre o snapshot do app e a API nesta primeira versão. Referências a turma, disciplina e usuário são verificadas nos comandos; índices únicos protegem carteira, entrega, crédito, correção, vínculo, matrícula e código. Antes de integrações externas que escrevam diretamente no banco, prefira promover cada entidade a tabela tipada com chaves estrangeiras. **Nenhum cliente escreve diretamente nos registros.**

Entidades: turmas (`classes`), disciplinas (`subjects`), matrículas (`enrollments`), atribuições (`assignments`), vínculos familiares (`links`), atividades (`activities`), entregas/validações (`submissions`), lembretes (`personal`), carteiras (`wallets`), movimentações (`ledger`), recompensas (`rewards`), resgates (`redemptions`), regras (`rules`), metas (`goals`), contribuições (`contributions`), conquistas (`achievements`), avisos (`notifications`) e auditoria (`audit`).

Todas as tabelas expostas têm RLS habilitada e não concedem escrita aos papéis cliente. Também revogamos leitura direta: `school_snapshot` é a única projeção permitida. As funções públicas verificam `auth.uid()`, escola e vínculos em cada chamada; funções auxiliares vivem no schema privado, com `search_path` fechado e execução revogada ao cliente. O snapshot da entrega contém somente nome da recompensa, código, local e estado. Contribuições coletivas são projetadas sem identificar alunos.

A autorização está duplicada de propósito entre motor demonstrativo e PostgreSQL. Os testes exercitam os dois. O adapter real não calcula nem escreve saldo ou estoque no cliente. Sem conexão, a operação falha; não há fila financeira offline.

## Moedas e transações

Todos os comandos de uma escola adquirem primeiro um bloqueio transacional da linha de `schools`. Assim a versão inicial serializa alterações da mesma escola, incluindo lotes, consumo de estoque, correções e cadastros. Escolas distintas podem operar em paralelo. É uma escolha conservadora de consistência para a primeira versão: com maior volume, medir latência e migrar para bloqueios por carteira/recompensa com ordem fixa, preservando os testes de concorrência.

Cada validação elegível aumenta a participação validada, concede o crédito e insere uma referência única `entrega:participação`. Repetir a validação concluída é inofensivo. Uma repetição de missão exige limite total disponível e intervalo de 24 horas ou sete dias desde a validação anterior, conforme a publicação. Ajustes reutilizam a entrega ainda sem crédito. O atraso compara o prazo à entrega mais recente; conclusão, atraso e revisão são conceitos separados.

Reserva move valor de `available` para `reserved` e reduz estoque disponível na mesma transação. O preço e local ficam registrados no resgate, mesmo se o catálogo mudar. A entrega reduz somente `reserved`. Cancelar devolve saldo e estoque. Código é aleatório, de uso único, validado no contexto da escola. O banco real usa UUID aleatório com 128 bits em representação sem hífens; o demo usa 12 caracteres para facilitar exploração.

`request_id` torna repetições de uma solicitação de resgate idempotentes. O controller mantém esse identificador durante falhas e tentativas na mesma sessão. Após encerrar o app em uma resposta incerta, deve-se primeiro atualizar e conferir os resgates; não existe fila de operações persistida entre sessões.

Movimentações, contribuições, conquistas e auditoria não podem ser alteradas ou excluídas, inclusive pelo caminho interno comum. Correção é um estorno integral de ganho indevido, com justificativa mínima de dez caracteres e referência única ao original. Se as moedas já estiverem indisponíveis, o estorno é recusado, sem saldo negativo. Não existe desconto punitivo nem edição arbitrária do saldo. O total `earned` registra créditos brutos históricos; estornos aparecem separadamente. Gastar e corrigir não apagam medalhas. Auditoria registra autor, data, operação, referência e justificativa; validações em lote incluem os IDs das entregas.

## Interface e acessibilidade

Material 3, texto em pt-BR, superfícies claras, verde escuro e estrela amarela para a moeda. Layout usa coluna em telas pequenas e navegação lateral em telas largas. Estados possuem rótulos, não apenas cores. Botões têm rótulo/tooltip, formulários validam entradas e ações financeiras pedem confirmação. Testes verificam ausência de overflow em quatro larguras; validação com TalkBack/VoiceOver e fontes ampliadas deve ocorrer em dispositivos antes de uso real.

A demonstração reinicia com dados fictícios relativos à data local. O backend normaliza datas de comandos em UTC; a apresentação converte para horário local. Contas de responsáveis nunca recebem lembretes privados. Textos de notificações não identificam aluno, atividade ou recompensa.

## Integrações e extensões

Supabase hospedado, SMTP e Edge Function precisam ser configurados pela escola. Serviço de push FCM/APNs não está conectado; há avisos internos e agendamento local opt-in. Não há chamada financeira offline. Notificações são auxiliares: falha ao agendar não desfaz uma transação confirmada no servidor.

O app não apresenta um nome comercial definitivo. O pacote de desenvolvimento é `br.edu.portal.portal_escolar`; definir identificadores, marca e assinatura antes de distribuir. Os ícones de launcher gerados pelo Flutter são provisórios.

Conversão de Star Coins em pontos acadêmicos foi **deliberadamente excluída**. Qualquer proposta futura exige decisão explícita da escola sobre disciplinas elegíveis, limites, critérios, equidade, registro acadêmico e autorização do professor. Recompensa, participação e nota permanecem separadas. Não existem ranking público, streaks punitivos, compra de moedas ou dependência da alimentação regular em moedas.
