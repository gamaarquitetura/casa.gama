# Sincronização Hub para loja (botão "Enviar para Casa Gama")

Como funciona: no Hub, alguém clica no botão "Enviar para Casa Gama". O Hub monta a lista de produtos e manda para um endereço específico do projeto Supabase da loja (uma Edge Function), que recebe os dados e atualiza as tabelas `categorias` e `produtos` de lá. Os dois bancos continuam separados, o Hub nunca acessa o banco da loja diretamente, só conversa com esse endereço.

Duas peças para montar, uma em cada projeto Lovable.

## Peça 1: Edge Function no projeto da loja

Já está escrita em `supabase/functions/sync-produtos/index.ts`, pronta para levar para o projeto Casa Gama Shop no Lovable (colar o código, ou pedir para o Lovable criar com o prompt abaixo).

Antes de publicar, criar dois secrets no projeto da loja (Cloud > Secrets):

- `SYNC_SECRET`: uma senha longa e aleatória, só o Hub e a loja conhecem
- `SUPABASE_SERVICE_ROLE_KEY` e `SUPABASE_URL`: normalmente já existem automaticamente em todo projeto com Lovable Cloud ativado

### Prompt para colar no Lovable (projeto Casa Gama Shop)

```
Crie uma Edge Function chamada sync-produtos que recebe requisições POST
com o corpo { produtos: [...] }, onde cada produto tem os campos:
codigo, codigo_fornecedor, nome, categoria, preco, estoque, imagem_url,
disponivel.

A função deve:
1. Verificar o header x-sync-secret e comparar com o secret SYNC_SECRET.
   Se não bater, retornar 401.
2. Para cada produto, garantir que a categoria existe na tabela categorias
   (criar se não existir).
3. Fazer upsert do produto na tabela produtos usando o campo codigo como
   chave de conflito.
4. Retornar um JSON com { criados, atualizados, erros }, contando quantos
   produtos foram criados, quantos atualizados, e uma lista de erros por
   código de produto, se houver.

As tabelas categorias e produtos já existem no banco, seguindo esta
estrutura: [colar aqui o conteúdo de supabase/schema.sql]
```

## Peça 2: botão no Hub

O botão precisa morar na tela de gestão de produtos da Casa Gama dentro do Hub. Antes de montar, criar dois secrets no projeto do Hub (Cloud > Secrets):

- `CASA_GAMA_SYNC_URL`: o endereço da Edge Function da loja (Lovable mostra essa URL depois que a função é publicada)
- `CASA_GAMA_SYNC_SECRET`: o mesmo valor colocado em `SYNC_SECRET` no projeto da loja

### Prompt para colar no Lovable (projeto do Hub)

```
Na tela de gestão de produtos da Casa Gama, adicione um botão "Enviar
para Casa Gama".

Ao clicar:
1. Monta uma lista com todos os produtos cadastrados, no formato:
   codigo, codigo_fornecedor, nome, categoria, preco, estoque,
   imagem_url, disponivel.
2. Envia um POST para a URL guardada no secret CASA_GAMA_SYNC_URL, com
   o header x-sync-secret preenchido com o valor do secret
   CASA_GAMA_SYNC_SECRET, e corpo { produtos: [...] }.
3. Mostra o resultado para quem clicou: quantos produtos foram criados,
   quantos atualizados, e a lista de erros, se houver.

Produto novo (ainda não publicado) deve passar por uma tela de revisão
antes de habilitar o envio, mostrando nome, foto, preço e categoria,
com um botão "Publicar na loja" separado do "Enviar para Casa Gama" de
produtos já existentes.
```

## Depois

Com essas duas peças no ar, o fluxo manual já funciona: cadastra ou ajusta produto no Hub, clica em enviar, a loja atualiza. Falta o caminho de volta (loja para Hub, automático, refletindo baixa de estoque de cada venda), que é o próximo passo da migração.

## Correção crítica: loja estava lendo direto do banco do Hub (23/09/2026)

Ao testar a Peça 1, descobrimos que a vitrine da loja nunca usou o banco próprio do projeto Casa Gama Shop. O código lia `CASAGAMA_SUPABASE_URL`, uma variável configurada manualmente por quem construiu o site antes desta migração, apontando direto para o banco do Hub (`bqiseblawwjkehulzztd`). O banco próprio do Shop (`xpdllzmxewrcjdwvxmuo`) ficou vazio e sem uso o tempo todo. Confirmado direto no código-fonte (`src/lib/supabase.server.ts` e `src/routes/api/public/sync-produtos.ts`), não por suposição.

Isso quebrava o isolamento decidido (loja separada do banco de produção do escritório, sem acesso ao financeiro e outras tabelas sensíveis). Decisão: migrar a loja para o banco próprio, restaurando o isolamento.

### Prompt de migração (colar no Lovable, projeto Casa Gama Shop)

```
Vamos corrigir um problema de arquitetura: esta loja está lendo o
catálogo direto do banco de produção do Hub (bqiseblawwjkehulzztd),
através da variável CASAGAMA_SUPABASE_URL, em vez de usar o banco
próprio deste projeto (xpdllzmxewrcjdwvxmuo, hoje vazio). Isso expõe a
loja pública ao mesmo banco que guarda financeiro e notas fiscais do
escritório, o que não deveria acontecer.

Preciso que você faça a migração para isolar a loja, nesta ordem:

1. Criar a estrutura no banco próprio
No banco próprio deste projeto (xpdllzmxewrcjdwvxmuo), crie as tabelas
casagama_produtos e casagama_categorias, com a mesma estrutura já
usada hoje:
- casagama_produtos: codigo, nome, categoria, preco, imagem_url,
  quantidade_estoque, ativo
- casagama_categorias: nome

2. Copiar os dados atuais
Copie os 92 produtos e as categorias que estão hoje no banco do Hub
para essas tabelas novas, no banco próprio. Confira que os 92 produtos
e todas as categorias vieram completos.

3. Configurar RLS no banco próprio
Leitura pública liberada em casagama_produtos e casagama_categorias (a
vitrine precisa ler sem login). Escrita restrita à chave de serviço
(nenhuma escrita pela chave pública).

4. Trocar a conexão da vitrine
Em src/lib/supabase.server.ts, troque a leitura de
CASAGAMA_SUPABASE_URL para usar o banco próprio deste projeto (a
mesma URL que SUPABASE_SERVICE_ROLE_KEY automática já aponta), no
lugar da URL do Hub.

5. Trocar a conexão da função de sincronização
Em src/routes/api/public/sync-produtos.ts, faça o mesmo ajuste: usar o
banco próprio e a chave de serviço automática deste projeto, em vez de
depender de um secret manual.

6. Testar antes de limpar
Depois de trocar, teste a vitrine e teste um envio de produto via
sincronização, para confirmar que tudo funciona com o banco novo,
antes de mexer em qualquer coisa do Hub.

7. Só então, limpar o que sobrou
Remova a variável antiga CASAGAMA_SUPABASE_URL (a que apontava pro
Hub) e o secret CASAGAMA_SUPABASE_SERVICE_ROLE_KEY, que deixam de ser
necessários.

Vá confirmando cada etapa antes de aplicar a próxima, e me avise se
algo ficar ambíguo.
```

# Sincronização loja para Hub (baixa de estoque automática)

Como funciona: no momento em que o cliente finaliza o pedido pelo WhatsApp, a loja já desconta o estoque no próprio banco dela (decisão já confirmada, sem reserva temporária). Nesse mesmo instante, a loja registra o pedido num histórico (que não existia antes) e manda a lista de itens vendidos para um endereço do Hub, que desconta o mesmo estoque na tabela dele. Não tem botão, não depende de ninguém conferir nada. Se a chamada falhar, o pedido fica marcado como não sincronizado e uma rotina programada tenta de novo sozinha.

Duas peças, uma em cada projeto. Monte a Peça 2 (Hub) primeiro, porque a Peça 1 (loja) precisa da URL que só existe depois da função do Hub publicada.

## Peça 1: histórico de pedido e envio automático, no projeto da loja

Antes de montar, criar dois secrets no projeto da loja (Cloud > Secrets):

- `HUB_VENDA_URL`: o endereço da Edge Function do Hub que vai receber a venda (só existe depois da Peça 2 estar publicada)
- `VENDA_SYNC_SECRET`: `79b49649b5fb9026de6e213fbf44575e3d68783c6a5f475cc1a006edce06c953`

### Prompt para colar no Lovable (projeto Casa Gama Shop)

```
Crie duas tabelas no banco próprio deste projeto:

casagama_pedidos: id, criado_em, valor_base, valor_final,
forma_pagamento, presente (boolean), mensagem_presente,
sincronizado_hub (boolean, default false)

casagama_pedido_itens: id, pedido_id (referência a casagama_pedidos),
codigo_produto, nome_produto, preco_unitario, quantidade

No fluxo de finalizar pedido (o mesmo que hoje monta a mensagem do
WhatsApp e desconta o estoque local), adicione, no mesmo momento:

1. Gravar o pedido em casagama_pedidos e os itens em
   casagama_pedido_itens.
2. Enviar um POST para a URL guardada no secret HUB_VENDA_URL, com
   header x-venda-secret preenchido com o secret VENDA_SYNC_SECRET, e
   corpo { pedido_id, itens: [{ codigo, quantidade }] }.
3. Se a resposta for de sucesso, marcar sincronizado_hub como true
   nesse pedido. Se falhar (erro de rede, timeout, resposta de erro),
   deixar sincronizado_hub como false, sem travar a finalização do
   pedido para o cliente.

Crie também um Job (Cloud > Jobs) que roda a cada 15 minutos: busca
pedidos com sincronizado_hub false, reenvia cada um para o mesmo
endereço, e marca como sincronizado quando der certo.
```

## Peça 2: recebimento da venda, no projeto do Hub

Antes de montar, criar um secret no projeto do Hub (Cloud > Secrets):

- `VENDA_SYNC_SECRET`: o mesmo valor de cima, `79b49649b5fb9026de6e213fbf44575e3d68783c6a5f475cc1a006edce06c953`

### Prompt para colar no Lovable (projeto do Hub)

```
Crie uma Edge Function chamada registrar-venda que recebe POST com o
corpo { pedido_id, itens: [{ codigo, quantidade }] }.

A função deve:
1. Verificar o header x-venda-secret e comparar com o secret
   VENDA_SYNC_SECRET. Se não bater, retornar 401.
2. Para cada item, localizar o produto em casagama_produtos pelo
   codigo e descontar quantidade_estoque pela quantidade vendida, sem
   deixar o valor ficar negativo (mínimo zero). Se o estoque chegar a
   zero, marcar ativo como false.
3. Retornar um JSON com { atualizados, erros }, contando quantos itens
   foram descontados com sucesso e uma lista de erros por código de
   produto, se houver (por exemplo, produto não encontrado).
```

## Depois

Assim que a Peça 2 estiver publicada no Hub, copie a URL da função `registrar-venda` para o secret `HUB_VENDA_URL` no projeto da loja, antes de publicar a Peça 1. Teste com uma venda de exemplo antes de considerar pronto: confirme que o estoque caiu nos dois bancos e que o pedido de teste ficou marcado como sincronizado.
