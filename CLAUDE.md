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

1. Migrar dados de produto e estoque do Firestore para as tabelas reais da loja (ver "Estrutura real confirmada" abaixo)
2. **Concluído em 22/09/2026, corrigido em 23/09/2026**: rotina de sincronização Hub para loja (botão "Enviar para Casa Gama"), cobrindo produto novo (com área de revisão e botão "Publicar na loja") e ajuste de estoque. Desenho original e os prompts usados em `docs/sincronizacao-hub-loja.md`. Do lado da loja, a Edge Function real ficou em `POST /api/public/sync-produtos`, protegida por header `x-sync-secret`. O segredo de sincronização foi gerado nesta sessão e cadastrado nos dois projetos (Lovable Cloud > Secrets), não fica salvo em nenhum arquivo deste repositório
3. **Concluído e validado em 23/09/2026**: rotina automática de volta (loja para Hub) para refletir a baixa de estoque de cada venda. Desenho e prompts em `docs/sincronizacao-hub-loja.md`, seção "Sincronização loja para Hub". Cria histórico de pedido na loja (`casagama_pedidos`/`casagama_pedido_itens`, que não existia antes), envia a venda pro Hub via Edge Function `registrar-venda` protegida por header `x-venda-secret`, com reenvio automático por Job programado se a primeira tentativa falhar. Segredo gerado nesta sessão, cadastrado nos dois projetos, não fica salvo em arquivo deste repositório

Lado da loja testado e comprovado com números reais (pedido gravado, item gravado, estoque descontado e restaurado, senha errada recusada). Lado do Hub: o endpoint `POST /api/public/registrar-venda` existia só na prévia do editor, foi publicado em produção em 23/09/2026 e testado lá (200 com senha certa, 401 com senha errada, sem alterar estoque real no teste).

**Teste final de ponta a ponta, com pedido real feito pelo site (23/09/2026)**: produto CG-PR-004, 1 unidade, pagamento PIX. Pedido gravado em `casagama_pedidos` (valor base 56,26, total 53,45 com desconto de 5%), item gravado em `casagama_pedido_itens`. Estoque caiu de 4 para 3 na loja e de 4 para 3 no Hub, conferido direto no banco do Hub, não só pela resposta da chamada. `sincronizado_hub` ficou `true`. As quatro checagens bateram, a sincronização automática loja para Hub está funcionando de ponta a ponta. Limpeza: pedido de teste apagado e estoque da loja restaurado para 4; o estoque do produto no Hub precisou ser restaurado manualmente para 4, porque o endpoint `registrar-venda` só desconta, não tem função de restaurar (desenho intencional, limita o que a loja pode fazer no banco do Hub a essa única operação).

**Achado de segurança durante a publicação do Hub (23/09/2026)**: o scan de segurança do Lovable encontrou 24 regras de acesso frouxas no banco do Hub (achados "críticos" no sentido de regra de banco, não vazamento de senha ou chave). Fechado nesta sessão: as 7 tabelas da Casa Gama (`casagama_produtos`, `casagama_categorias`, `casagama_colecoes`, `casagama_config`, `casagama_notas_fiscais`, `casagama_notas_fiscais_itens`, `casagama_produtos_historico_preco`) agora só permitem cadastrar, alterar ou apagar para usuários com papel de administração; leitura segue liberada para qualquer logado, e a vitrine da loja continua lendo produtos/categorias ativos normalmente.

**Pendente, fora do escopo desta migração, mas importante**: o portal do cliente (`projetos`, `projeto_fases`, `projeto_diario`, `portal_updates`, `fase_documentos`, `fase_checklist_items`) libera acesso com base em um dado que o próprio visitante envia no pedido, sem verificação de identidade. Risco: alguém que descubra o formato desse dado pode potencialmente ver o projeto de outro cliente. Achado pelo próprio Lovable como "o mais sério na prática". Também pendente: dados internos do escritório (ausências, precificação, cotações, custos) legíveis por qualquer usuário logado no Hub, e a tabela `portal_settings` legível publicamente sem login (só tem configuração de aparência, risco baixo). Recomendação: tratar isso numa sessão dedicada de segurança do Hub, não misturado com a migração da Casa Gama.

### Falha crítica encontrada e correção (23/09/2026)

Ao testar a sincronização, descobrimos que a vitrine da loja nunca usou o banco próprio do projeto Casa Gama Shop: o código lia uma variável `CASAGAMA_SUPABASE_URL`, configurada manualmente por quem construiu o site antes desta migração, apontando direto para o banco de produção do Hub (`bqiseblawwjkehulzztd`). O banco próprio do Shop (`xpdllzmxewrcjdwvxmuo`) ficou vazio e sem uso o tempo todo. Confirmado direto no código-fonte (`src/lib/supabase.server.ts` e `src/routes/api/public/sync-produtos.ts`), depois de duas respostas contraditórias dos Lovable AI do Hub e da loja sobre se os bancos eram o mesmo ou não.

Isso quebrava o isolamento decidido: a loja pública tinha acesso ao mesmo banco que guarda financeiro e notas fiscais do escritório, sem nenhuma separação. Decisão confirmada pelas sócias: migrar a loja para o banco próprio, restaurando o isolamento (mantendo a Opção B já decidida, em vez de aceitar o compartilhamento que estava acontecendo de fato). Prompt de migração completo em `docs/sincronizacao-hub-loja.md`, seção "Correção crítica".

**Migração concluída e validada em 23/09/2026.** Evidências conferidas antes de aprovar:

- Catálogo criado no banco próprio da loja (`xpdllzmxewrcjdwvxmuo`): `casagama_produtos` com 92 linhas (92 ativos, 32 com estoque), `casagama_categorias` com 11 linhas, copiados do Hub
- Isolamento comprovado por teste de sentinela: produto criado só no banco da loja apareceu na vitrine; consulta ao banco do Hub não encontrou esse produto, confirmando que a vitrine não lê mais de lá
- Vitrine testada ao vivo: 92 peças, 32 disponíveis, sem erros. Contador reagiu em tempo real ao criar e remover o produto sentinela
- Sincronização testada contra o banco novo: envio com sucesso, chave errada continua sendo recusada com 401
- Secrets antigos removidos do Casa Gama Shop (`CASAGAMA_SUPABASE_URL`, `CASAGAMA_SUPABASE_SERVICE_ROLE_KEY`, `CASAGAMA_SUPABASE_PUBLISHABLE_KEY`), não são mais usados por nenhum código

A loja hoje não tem mais nenhum contato com o banco do Hub. `sync-produtos` grava no banco próprio da loja usando a chave de serviço automática do próprio projeto, sem depender de secret manual.
4. **Em andamento em 24/09/2026**: continuar a construção do site da loja no Lovable, com o admin de produtos morando no Hub. Checklist feito contra o sistema antigo (`casa-gama-v7.html`): 5 itens já prontos (vitrine com filtro, ficha de produto, forma de pagamento com desconto, presente com mensagem, produto indisponível visível), 3 parciais, 2 ausentes na hora do checklist.

   Fechado nesta sessão:
   - Quantidade ajustável no carrinho (antes cada produto só entrava 1 vez), com limite pelo estoque disponível
   - WhatsApp abre automaticamente ao finalizar o pedido, com botão "Copiar mensagem" como alternativa se o navegador bloquear o pop-up (decisão confirmada pelas sócias, revertendo a escolha anterior de só copiar mensagem)
   - Botão "avisar quando disponível" em produto sem estoque, abre WhatsApp com mensagem pronta
   - Tabela `casagama_config` (linha única) no banco próprio da loja: WhatsApp e chave PIX já preenchidos e em uso pelo site; Instagram, textos, horário e localização com campo pronto, ainda sem lugar na tela que mostre (não é bug, só não foi pedido ainda)
   - Limpeza: 3 secrets órfãos removidos do Casa Gama Shop (`CASAGAMA_SUPABASE_URL`, `CASAGAMA_SUPABASE_PUBLISHABLE_KEY`, `CASAGAMA_SUPABASE_SERVICE_ROLE_KEY`), confirmado zero referência no código antes de apagar
   - Estoque de teste restaurado no Hub: CG-PR-004 e CG-BD-001 de volta aos valores originais
   - Bug corrigido no Hub: o botão "Enviar para Casa Gama" nascia com contagem 0 e desativado, porque a marcação "publicado na loja" vinha desligada para os ~92 produtos já cadastrados antes dessa marcação existir. Corrigido com um backfill único marcando os 92 existentes como publicados; produto novo continua nascendo com a marcação desligada, passando pela revisão normal

   Não considerado bug, decisão de marca já registrada no projeto: paleta usa musgo/oliva como cor principal e terracota só como destaque, diferente do sistema antigo que usava terracota como cor principal

   **Teste manual real do WhatsApp, feito pelas sócias (24/09/2026): bem-sucedido.** Pedido real com CG-BD-001 pelo site publicado, WhatsApp abriu certinho no navegador.

   **URL publicada da loja**: `https://casa-gama-charm.lovable.app`

   **Saga de depuração do botão "Enviar para Casa Gama" (24/09/2026)**: depois do teste real acima, o botão passou a falhar em cadeia, por dois problemas distintos e sucessivos:
   1. `CASA_GAMA_SYNC_URL` e `CASA_GAMA_SYNC_SECRET` (secrets do Hub) tinham sido trocados de campo ao salvar: a URL continha um texto curto sem formato de URL. Corrigido com os valores certos (URL confirmada de novo com o Shop, senha reconfirmada)
   2. Depois de corrigido o Hub, o envio passou a dar 401: o `SYNC_SECRET` salvo no projeto da loja (Shop) tinha só 15 caracteres, um valor errado, diferente do gerado nesta sessão. Corrigido para o valor certo (64 caracteres hex) nos dois lados

   Confirmado com o primeiro envio real completo: **92 enviados, 92 atualizados, 0 criados, 0 erros.** O botão "Enviar para Casa Gama" está funcionando de ponta a ponta pela primeira vez.
5. Plugar o Umami por último

### Modelo de dados mapeado (22/09/2026)

Levantamento feito a partir do `casa-gama-v7.html`, que hoje guarda os dados no `localStorage` do navegador (não fala direto com o Firestore, é uma ferramenta de gerar site estático), mas usa o mesmo modelo de campos da versão viva.

Campos encontrados: produto (código interno, código do fornecedor Mart Collection, nome, categoria, preço, estoque, imagem, disponível), categoria, forma de pagamento (nome, percentual de desconto/acréscimo), configurações da loja (WhatsApp, Instagram, textos, horário, localização).

Lacuna encontrada: o sistema legado não grava nenhum histórico de pedido, só desconta o estoque na hora e manda a mensagem pro WhatsApp. Como a baixa de estoque agora precisa voltar pro Hub automaticamente, foi criada uma tabela de pedido nova (que não existia antes) para registrar o que gerou cada baixa.

Proposta original de estrutura de tabelas em `supabase/schema.sql`. `formas_pagamento`, `configuracoes_loja`, `pedidos` e `pedido_itens` continuam só como proposta, ainda não confirmadas contra o que existe de verdade no Lovable.

### Estrutura real confirmada (22/09/2026)

Ao montar a sincronização, o Lovable revelou que as tabelas de produto já existiam no projeto da loja, criadas durante a construção da vitrine, com nomes diferentes do que eu tinha imaginado no `schema.sql`:

- `casagama_produtos` (não `produtos`): campos `codigo`, `nome`, `categoria`, `preco`, `imagem_url`, `quantidade_estoque` (não `estoque`), `ativo` (não `disponivel`). Sem campo `codigo_fornecedor` (o código do fornecedor Mart Collection não é guardado na loja, só serve de referência interna no cadastro)
- `casagama_categorias` (não `categorias`): lista de nomes de categoria

`supabase/schema.sql` e `supabase/seed_produtos.sql` já foram corrigidos para usar esses nomes reais. Os 90 produtos do `INIT_PRODS` do `casa-gama-v7.html` estão convertidos em `supabase/seed_produtos.sql`, pronto para rodar contra o banco real da loja.

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
