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
