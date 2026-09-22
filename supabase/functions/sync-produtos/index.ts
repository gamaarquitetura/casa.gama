// Casa Gama - recebe produtos/estoque enviados pelo Hub e atualiza o banco da loja.
// Protegida por header x-sync-secret, comparado com o secret SYNC_SECRET
// guardado nas Secrets deste projeto (Cloud > Secrets).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SYNC_SECRET = Deno.env.get('SYNC_SECRET')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

Deno.serve(async (req) => {
  if (req.headers.get('x-sync-secret') !== SYNC_SECRET) {
    return new Response(JSON.stringify({ erro: 'nao autorizado' }), { status: 401 })
  }

  const body = await req.json().catch(() => null)
  if (!body || !Array.isArray(body.produtos)) {
    return new Response(JSON.stringify({ erro: 'formato invalido, esperado { produtos: [...] }' }), { status: 400 })
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

  let criados = 0
  let atualizados = 0
  const erros: string[] = []

  for (const p of body.produtos) {
    const { data: categoria, error: catErro } = await supabase
      .from('categorias')
      .upsert({ nome: p.categoria }, { onConflict: 'nome' })
      .select('id')
      .single()

    if (catErro || !categoria) {
      erros.push(`${p.codigo}: ${catErro?.message ?? 'categoria nao resolvida'}`)
      continue
    }

    const { data: existente } = await supabase
      .from('produtos')
      .select('id')
      .eq('codigo', p.codigo)
      .maybeSingle()

    const { error: prodErro } = await supabase
      .from('produtos')
      .upsert(
        {
          codigo: p.codigo,
          codigo_fornecedor: p.codigo_fornecedor ?? null,
          nome: p.nome,
          categoria_id: categoria.id,
          preco: p.preco,
          estoque: p.estoque,
          imagem_url: p.imagem_url || null,
          disponivel: p.disponivel,
          atualizado_em: new Date().toISOString(),
        },
        { onConflict: 'codigo' },
      )

    if (prodErro) {
      erros.push(`${p.codigo}: ${prodErro.message}`)
    } else if (existente) {
      atualizados++
    } else {
      criados++
    }
  }

  return new Response(JSON.stringify({ criados, atualizados, erros }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
