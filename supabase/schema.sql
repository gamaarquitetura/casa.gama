-- Casa Gama - estrutura inicial do banco da loja (Supabase, projeto proprio, separado do Hub)
-- Baseado no modelo de dados do casa-gama-v7.html (legado)

create table categorias (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  criado_em timestamptz not null default now()
);

create table produtos (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique,              -- ex: CG-PR-001
  codigo_fornecedor text,                   -- codigo do produto na Mart Collection
  nome text not null,
  categoria_id uuid references categorias(id),
  preco numeric(10,2) not null,
  estoque integer not null default 0,
  imagem_url text,
  disponivel boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table formas_pagamento (
  id uuid primary key default gen_random_uuid(),
  nome text not null,                       -- PIX, Cartao, Boleto
  modificador_percentual numeric(5,2) not null default 0,  -- -5, 0, 2
  tipo text not null check (tipo in ('desconto','neutro','acrescimo')),
  ordem integer not null default 0
);

create table configuracoes_loja (
  id boolean primary key default true check (id),  -- linha unica (singleton)
  whatsapp text,
  instagram text,
  logo_url text,
  nome_loja text default 'Casa Gama',
  descricao_hero text,
  descricao_rodape text,
  horario_rodape text,
  localizacao_rodape text
);

-- Pedido nao existia no sistema legado (estoque era descontado sem deixar
-- registro). Criado aqui porque a baixa de estoque agora precisa voltar
-- para o Hub automaticamente, e isso exige saber o que gerou cada baixa.
create table pedidos (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  forma_pagamento_id uuid references formas_pagamento(id),
  valor_base numeric(10,2) not null,
  valor_final numeric(10,2) not null,
  presente boolean not null default false,
  mensagem_presente text,
  status text not null default 'enviado' check (status in ('enviado','confirmado','cancelado')),
  sincronizado_hub boolean not null default false
);

create table pedido_itens (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid references pedidos(id) on delete cascade,
  produto_id uuid references produtos(id),
  codigo_produto text not null,             -- copia do codigo no momento da venda
  nome_produto text not null,               -- copia do nome no momento da venda
  preco_unitario numeric(10,2) not null,
  quantidade integer not null
);

-- RLS: vitrine publica pode ler produtos, categorias e formas de pagamento.
-- Escrita fica restrita (sincronizacao Hub->loja usa a service role, nao a chave publica).
alter table categorias enable row level security;
alter table produtos enable row level security;
alter table formas_pagamento enable row level security;
alter table configuracoes_loja enable row level security;
alter table pedidos enable row level security;
alter table pedido_itens enable row level security;

create policy "leitura publica de categorias" on categorias for select using (true);
create policy "leitura publica de produtos" on produtos for select using (true);
create policy "leitura publica de formas de pagamento" on formas_pagamento for select using (true);
create policy "leitura publica de configuracoes" on configuracoes_loja for select using (true);

-- Cliente finalizando compra pode criar o pedido e seus itens
create policy "cliente cria pedido" on pedidos for insert with check (true);
create policy "cliente cria itens do pedido" on pedido_itens for insert with check (true);
