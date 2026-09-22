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

Segundo a documentação oficial do Lovable, é possível apontar um projeto para o mesmo Supabase que outro projeto já usa (é um caso previsto, tipo app do cliente + painel admin usando o mesmo banco). Antes de fazer essa troca, atenção aos avisos da própria documentação:

- Os dois projetos passam a ler e escrever nos mesmos dados, podem sobrescrever secrets um do outro e quebrar integrações um do outro se não houver cuidado
- É preciso configurar bem as políticas de RLS para não vazar dado entre loja e Hub
- O Lovable recomenda falar com o suporte deles (support@lovable.dev) para orientação de arquitetura nesse tipo de conexão, dado que o Hub já tem 122 tabelas em produção

### Ordem de execução combinada

1. Conectar o projeto da loja no Lovable ao mesmo projeto Supabase do Hub (hoje está em um banco separado e vazio), com cuidado nas políticas de RLS
2. Migrar dados de produto e estoque do Firestore para esse banco
3. Continuar a construção do site da loja no Lovable, com o admin de produtos morando no Hub
4. Plugar o Umami por último

### Checkout e baixa de estoque (confirmado em 22/09/2026)

O checkout continua via WhatsApp, igual ao sistema atual: cliente monta o carrinho e envia o pedido pelo WhatsApp, sem pagamento online na hora.

Decisão: baixa de estoque automática no momento em que o cliente envia o pedido, não por reserva temporária. Risco aceito pelas sócias: como o pagamento é combinado depois, por fora, se o cliente desistir ou não fechar a compra, o estoque fica reduzido indevidamente até alguém perceber e corrigir manualmente no Hub.

### Ainda em aberto

- Se a conexão da loja ao Supabase do Hub vai ser direta (Opção A: mesmo banco com RLS restringindo por tabela) ou por sincronização entre bancos separados (Opção B: loja mantém banco próprio, só troca produto e estoque)
- Se a atualização de produto novo (cadastro, fotos, descrição) do Hub para a loja é automática ou passa por um botão de revisão manual antes de publicar

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
