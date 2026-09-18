import '../core/models.dart';

JsonMap demoSeed(DateTime now) {
  String day(int offset) =>
      DateTime(now.year, now.month, now.day + offset, 18).toIso8601String();
  final activities = <JsonMap>[
    {
      'id': 'a1',
      'title': 'Um pequeno ecossistema',
      'description':
          'Observe um ambiente perto de você e registre como os seres vivos se relacionam.',
      'kind': 'academic',
      'category': 'Investigação',
      'subject': 'Ciências',
      'coins': 10,
      'due_at': day(1),
      'criteria':
          'Descrever três seres vivos e duas relações entre eles. Alternativa acessível: relato em texto com apoio de um adulto.',
      'validator': 'teacher',
      'collective': false,
    },
    {
      'id': 'a2',
      'title': 'Cada material no seu lugar',
      'description': 'Ajude a organizar os materiais compartilhados da turma.',
      'kind': 'practice',
      'category': 'Colaboração',
      'subject': '',
      'coins': 15,
      'due_at': day(2),
      'criteria':
          'Separar e guardar cinco materiais, ou elaborar a lista de organização com um colega.',
      'validator': 'teacher',
      'collective': true,
    },
    {
      'id': 'a3',
      'title': 'Juntos, uma escola mais verde',
      'description':
          'Nossa turma está cuidando da coleta seletiva. Cada participação faz diferença.',
      'kind': 'collective',
      'category': 'Colaboração',
      'subject': '',
      'coins': 20,
      'due_at': day(4),
      'criteria':
          'Identificar três resíduos e o destino correto. Alternativa: criar orientações em texto.',
      'validator': 'teacher',
      'collective': true,
    },
    {
      'id': 'a4',
      'title': 'Uma história para compartilhar',
      'description':
          'Escolha uma leitura e compartilhe uma descoberta com a família.',
      'kind': 'practice',
      'category': 'Leitura',
      'subject': '',
      'coins': 15,
      'due_at': day(3),
      'criteria':
          'Ler ou ouvir um texto e registrar uma ideia. Responsável confirma a conversa.',
      'validator': 'guardian',
      'collective': false,
    },
  ];
  for (final a in activities) {
    a.addAll({
      'school_id': 'school',
      'class_id': 'c1',
      'teacher_id': 'teacher',
      'start_at': day(-2),
      'frequency': 'once',
      'limit': 1,
      'cancelled': false,
    });
  }
  return {
    'profiles': [
      {
        'id': 'student',
        'name': 'Lia Oliveira',
        'role': 'student',
        'school_id': 'school',
      },
      {
        'id': 'student2',
        'name': 'Caio Santos',
        'role': 'student',
        'school_id': 'school',
      },
      {
        'id': 'teacher',
        'name': 'Prof. Rafael',
        'role': 'teacher',
        'school_id': 'school',
      },
      {
        'id': 'coordinator',
        'name': 'Ana • Coordenação',
        'role': 'coordinator',
        'school_id': 'school',
      },
      {
        'id': 'guardian',
        'name': 'Marina Oliveira',
        'role': 'guardian',
        'school_id': 'school',
      },
      {
        'id': 'delivery',
        'name': 'Equipe de retirada',
        'role': 'delivery',
        'school_id': 'school',
      },
    ],
    'classes': [
      {'id': 'c1', 'name': '7º ano A', 'school_id': 'school'},
    ],
    'subjects': [
      {'id': 'Ciências', 'name': 'Ciências'},
      {'id': 'Português', 'name': 'Português'},
    ],
    'enrollments': [
      {'id': 'e1', 'student_id': 'student', 'class_id': 'c1'},
      {'id': 'e2', 'student_id': 'student2', 'class_id': 'c1'},
    ],
    'assignments': [
      {
        'id': 't1',
        'teacher_id': 'teacher',
        'class_id': 'c1',
        'subject': 'Ciências',
      },
    ],
    'links': [
      {'id': 'l1', 'guardian_id': 'guardian', 'student_id': 'student'},
    ],
    'activities': activities,
    'submissions': <JsonMap>[],
    'personal': <JsonMap>[],
    'wallets': [
      {'student_id': 'student', 'available': 40, 'reserved': 0, 'earned': 40},
      {'student_id': 'student2', 'available': 40, 'reserved': 0, 'earned': 40},
    ],
    'ledger': [
      for (final s in ['student', 'student2'])
        {
          'id': 'opening-$s',
          'student_id': s,
          'kind': 'gain',
          'amount': 40,
          'title': 'Participações anteriores • exemplo fictício',
          'actor': 'Coordenação',
          'at': day(-3),
          'reference': 'demo-opening',
        },
    ],
    'rewards': [
      {
        'id': 'r1',
        'name': 'Adesivos que inspiram',
        'description': 'Uma cartela para deixar seus materiais com a sua cara.',
        'price': 30,
        'stock': 12,
        'limit': 2,
        'location': 'Biblioteca',
        'instructions': 'Apresente o código no intervalo.',
        'start_at': day(-30),
        'end_at': day(90),
        'icon': 'sticker',
      },
      {
        'id': 'r2',
        'name': 'Lanche especial',
        'description':
            'Uma opção extra. A alimentação regular é um direito e não depende de moedas.',
        'price': 60,
        'stock': 8,
        'limit': 1,
        'location': 'Cantina',
        'instructions':
            'Retire no intervalo. Consulte os ingredientes com a equipe.',
        'start_at': day(-30),
        'end_at': day(90),
        'icon': 'snack',
      },
      {
        'id': 'r3',
        'name': 'Kit de novas ideias',
        'description': 'Um pequeno brinde escolar para grandes descobertas.',
        'price': 100,
        'stock': 5,
        'limit': 1,
        'location': 'Secretaria',
        'instructions': 'Retire no horário de atendimento.',
        'start_at': day(-30),
        'end_at': day(90),
        'icon': 'gift',
      },
    ],
    'redemptions': <JsonMap>[],
    'audit': <JsonMap>[],
    'notifications': <JsonMap>[],
    'rules': [
      {'id': 'academic', 'name': 'Atividade escolar', 'coins': 10},
      {'id': 'practice', 'name': 'Boa prática', 'coins': 15},
      {'id': 'collective', 'name': 'Projeto coletivo', 'coins': 20},
    ],
    'goals': [
      {
        'id': 'g1',
        'class_id': 'c1',
        'name': 'Nossa turma faz a diferença',
        'description':
            'Vamos somar 20 participações em missões de colaboração.',
        'target': 20,
      },
    ],
    'contributions': <JsonMap>[],
    'achievements': <JsonMap>[],
  };
}
