# Casa Gama - Contexto do Projeto

Documento de referência para desenvolvimento neste repositório. Atualizado em 22/09/2026.

## Sobre o escritório

GAMA Arquitetura, duas sócias (Mariane e Gabriela), sediado em Quaraí/RS, fronteira com o Uruguai. CNPJ 56.428.577/0001-53.

Dois produtos internos em desenvolvimento:

- GAMA Hub: plataforma interna de gestão do escritório (repositório separado, construído no Lovable)
- Casa Gama: loja de decoração com e-commerce próprio (este repositório)

## Situação atual do Casa Gama (legado)

Este repositório contém hoje `casa-gama-v7.html`, sistema legado ainda no ar:

- Página única HTML com duas áreas: loja pública e painel admin (aberto via hash secreta na URL)
- Backend: Firebase Firestore, com listeners `onSnapshot` em tempo real
- Checkout via WhatsApp, com desconto de 5% para pagamento em PIX ou dinheiro
- Deploy no Netlify, repositório GitHub original `gfdequadros/casagama`

## Decisão de migração (set/2026)

A loja pública da Casa Gama continua como aplicação separada do GAMA Hub: o Hub é gestão interna, a loja é venda ao público. A loja se conecta ao Hub apenas para dados compartilhados:

- Estoque e produtos
- Financeiro
- Analytics do site (origem de tráfego, cliques), alimentando o Hub

### Decisões técnicas confirmadas

- Nova loja da Casa Gama sendo construída no Lovable (desenvolvimento já iniciado). Projeto: lovable.dev/projects/c95ebbd0-58f5-4b53-b69c-cfe9183f7f73
- Hospedagem passa a ser o próprio publish do Lovable, não mais Netlify. A decisão anterior de sair do Netlify para Vercel ou Cloudflare Pages fica sem efeito, já que o Lovable resolve a hospedagem nativamente
- Admin da loja fica dentro do GAMA Hub, e não em painel próprio da loja, para evitar duplicar gestão em dois lugares
- Analytics: Umami self-hosted (gratuito, sem custo recorrente novo), usando o mesmo banco Postgres do Supabase que já serve o Hub

**Confirmado em 22/09/2026**: o projeto Casa Gama Shop no Lovable está com banco próprio, criado automaticamente, ainda vazio (0 tabelas). Ou seja, hoje ele não está ligado ao Supabase do Hub.

### Arquitetura de conexão Hub / Loja (confirmado em 22/09/2026)

Decisão: bancos separados (o Hub mantém seu Supabase, a loja mantém o dela), sem conexão direta entre os dois. A troca de dado é feita por sincronização, só do que for necessário (produto e estoque), nunca dando à loja acesso às 122 tabelas do Hub.

Sentido Hub para loja, manual: cadastro de produto novo, edição (fotos, descrição) e ajuste de estoque feitos no Hub só chegam na loja quando alguém clica em um botão "Enviar para Casa Gama". Produto novo também passa por um botão de revisão manual antes de publicar, não vai direto pro ar.

Sentido loja para Hub, automático: quando uma venda acontece na loja e o estoque cai lá, essa baixa volta pro Hub sozinha, sem precisar de botão nem conferência manual. É o único trecho da sincronização que roda nos dois sentidos sem ação humana, porque reflete uma venda já feita.

### Ordem de execução combinada

1. Migrar dados de produto e estoque do Firestore para uma estrutura de tabelas no banco Supabase próprio da loja (o que já existe vazio hoje)
2. Montar a rotina de sincronização Hub para loja (botão "Enviar para Casa Gama"), cobrindo produto novo e ajuste de estoque
3. Montar a rotina automática de volta (loja para Hub) para refletir a baixa de estoque de cada venda
4. Continuar a construção do site da loja no Lovable, com o admin de produtos morando no Hub
5. Plugar o Umami por último

### Modelo de dados mapeado (22/09/2026)

Levantamento feito a partir do `casa-gama-v7.html`, que hoje guarda os dados no `localStorage` do navegador (não fala direto com o Firestore, é uma ferramenta de gerar site estático), mas usa o mesmo modelo de campos da versão viva.

Campos encontrados: produto (código interno, código do fornecedor Mart Collection, nome, categoria, preço, estoque, imagem, disponível), categoria, forma de pagamento (nome, percentual de desconto/acréscimo), configurações da loja (WhatsApp, Instagram, textos, horário, localização).

Lacuna encontrada: o sistema legado não grava nenhum histórico de pedido, só desconta o estoque na hora e manda a mensagem pro WhatsApp. Como a baixa de estoque agora precisa voltar pro Hub automaticamente, foi criada uma tabela de pedido nova (que não existia antes) para registrar o que gerou cada baixa.

Proposta de estrutura de tabelas para o banco da loja em `supabase/schema.sql`, pronta para colar no SQL editor do Supabase quando o banco da loja estiver definido: categorias, produtos, formas_pagamento, configuracoes_loja, pedidos, pedido_itens, com RLS já esboçado (leitura pública de vitrine, escrita restrita).

Os 90 produtos que hoje estão no `INIT_PRODS` do `casa-gama-v7.html` já foram convertidos para esse formato novo, em `supabase/seed_produtos.sql`. Rodar depois do `schema.sql`, no banco próprio da loja.

### Checkout e baixa de estoque (confirmado em 22/09/2026)

O checkout continua via WhatsApp, igual ao sistema atual: cliente monta o carrinho e envia o pedido pelo WhatsApp, sem pagamento online na hora.

Decisão: baixa de estoque automática no momento em que o cliente envia o pedido, não por reserva temporária. Essa baixa acontece no banco da própria loja e volta pro Hub automaticamente. Risco aceito pelas sócias: como o pagamento é combinado depois, por fora, se o cliente desistir ou não fechar a compra, o estoque fica reduzido indevidamente até alguém perceber e corrigir manualmente.

## Banco de dados (Supabase via Lovable Cloud)

O GAMA Hub não usa uma conta Supabase externa com login próprio em supabase.com. Ele usa o Lovable Cloud, backend nativo do Lovable construído sobre Supabase, gerenciado dentro do painel do Lovable (menu de três pontinhos > Mais > Cloud). Lá estão Database (122 tabelas), Users, Storage (8 buckets), Secrets, Edge functions, SQL editor e Logs.

Não há conector Supabase externo ativado no projeto do Hub. Quando este projeto (Casa Gama) precisar consultar ou gravar nesse mesmo banco, o caminho é usar as credenciais expostas pelo Lovable Cloud (`VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY`), não uma conexão externa própria.

## Outras ferramentas em uso no escritório

Google Workspace, Canva Pro, WhatsApp Business (uma conta por marca), Sicredi e Nubank (contas compartilhadas, controles financeiros separados), ArchiCAD 27, SketchUp, layout SketchUp.

## Diretrizes de estilo para conteúdo e respostas

- Linguagem prática e aplicada à realidade da empresa
- Nada de teoria abstrata
- Nada de emojis
- Nada de travessão (usar vírgula, dois pontos ou ponto)
