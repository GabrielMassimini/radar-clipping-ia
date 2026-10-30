# Agente 1 – Triagem

Classifica as notícias coletadas: se são relevantes para o tema, o tom e a aderência em relação ao cliente, quais mensagens-chave aparecem e um resumo curto.

- **Modelo:** Gemini Flash-Lite (barato e rápido; a triagem é a etapa com mais chamadas)
- **Temperatura:** 0.2 (respostas mais previsíveis, menos "criativas")
- **Entrada:** lotes de até 10 notícias (id, veículo e título), mais o tema, o foco do cliente e as mensagens-chave do nó Configuração
- **Saída:** JSON validado pelo Structured Output Parser do n8n (schema abaixo)

> Limitação conhecida: o RSS do Google News não traz trecho da matéria, só título e veículo. Por isso a triagem decide pelo título.

## Prompt de sistema

O texto entre `{{ }}` é preenchido pelo n8n a cada execução.

```
Você é um analista de clipping de uma assessoria de imprensa. Sua tarefa é fazer a triagem de notícias sobre o tema "{{ tema }}" para um cliente.

Quem é o cliente e o que interessa a ele:
{{ foco_do_cliente }}

De cada notícia você recebe só o id, o veículo e o título. Decida apenas com base nesse texto.

Regras:
1. relevante = true quando o assunto principal da notícia for o próprio tema: o mercado, o setor, os produtos (incluindo lançamentos, avaliações e saída de linha), dados, estudos, pesquisas, vendas, preços, crédito, tendências ou regulamentação.
2. A relevância depende só do tema, não do foco do cliente. Uma notícia do tema que está longe dos interesses do cliente continua relevante, com aderencia "baixa".
3. relevante = false quando o tema aparece só como detalhe de uma notícia sobre outro assunto (ocorrências policiais, crimes, acidentes, sorteios, celebridades), e também para anúncios, ofertas e promoções de lojas ou marcas (por exemplo, títulos com "feirão", "oferta" ou "a partir de R$").
4. Se o título não deixa claro do que a notícia trata, relevante = false.
5. sentimento: o tom da notícia para o negócio do cliente. "positivo" se a notícia é boa para ele, "negativo" se é ruim, "neutro" se não afeta ou na dúvida.
6. aderencia: o quanto a notícia está perto dos interesses do cliente descritos acima. "alta" se trata diretamente deles, "media" se trata do setor de forma geral, "baixa" se é do tema mas distante do cliente.
7. mensagens_chave: marque só as mensagens da lista configurada que aparecem de fato no título, escritas exatamente como estão na lista. Se nenhuma aparecer, devolva uma lista vazia. Não deduza mensagens que o título não traz.
8. resumo: uma frase de até 25 palavras, em português, reescrevendo o título. Pode manter os números e nomes que estão no título, mas nunca acrescente informações que não estejam nele.
9. motivo: uma frase explicando por que a notícia é ou não relevante.
10. id: devolva o número exatamente como recebeu, sem colchetes. Devolva uma classificação para cada id recebido, sem pular nem inventar ids.
11. O cliente atua no Brasil. Notícias sobre outros países seguem as mesmas regras de relevância, mas a aderencia é no máximo "baixa", a não ser que o título trate de efeito no Brasil.
```

## Mensagem com as notícias

Montada pelo nó **Montar lotes**:

```
Mensagens-chave configuradas:
- {{ mensagem 1 }}
- {{ mensagem 2 }}

Notícias:
[1] (Veículo) Título da notícia
[2] (Veículo) Título da notícia
```

## Schema da saída

```json
{
  "type": "object",
  "properties": {
    "classificacoes": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": ["integer", "string"] },
          "relevante": { "type": "boolean" },
          "sentimento": { "type": "string", "enum": ["positivo", "neutro", "negativo"] },
          "aderencia": { "type": "string", "enum": ["alta", "media", "baixa"] },
          "mensagens_chave": { "type": "array", "items": { "type": "string" } },
          "resumo": { "type": "string" },
          "motivo": { "type": "string" }
        },
        "required": ["id", "relevante", "sentimento", "aderencia", "mensagens_chave", "resumo", "motivo"]
      }
    }
  },
  "required": ["classificacoes"]
}
```

## Decisões

- **Lotes de 10 em vez de uma notícia por vez:** cerca de 174 notícias por dia virariam 174 chamadas, perto do limite do plano gratuito do Gemini. Em lotes são cerca de 18 chamadas. Cada notícia leva um `id`, e o nó seguinte confere se voltaram todos.
- **Tom e aderência separados:** uma notícia pode estar muito perto dos interesses do cliente e ser ruim para ele (por exemplo, sobre golpes no setor). É justamente essa que a assessoria mais precisa ver, então as duas medidas ficam registradas.
- **Prompt genérico:** o tema, o foco do cliente e as mensagens-chave vêm do nó Configuração. O mesmo prompt serve para qualquer tema, e nenhum cliente real aparece no repositório.
- **Relevância com critério de assessoria:** só entra notícia em que o tema é o assunto principal. Ocorrências policiais, sorteios e anúncios ficam de fora.
- **Na dúvida, não relevante:** é melhor descartar uma notícia ambígua do que encher o relatório de ruído.

## Ajustes feitos nos testes

**Teste 1 (2 lotes, 20 notícias)**

- **Formato:** os 2 lotes foram recusados pelo Structured Output Parser. A causa principal estava na configuração do nó: o Schema Type ficou em "Generate From JSON Example", então o n8n tratou o schema como um *exemplo* de resposta e passou a exigir campos como `type` e `properties`. Correção: Schema Type = "Define using JSON Schema". Além disso, o modelo devolvia o `id` às vezes como número (`1`) e às vezes como texto (`"1"`, `"[1]"`, copiando o formato da mensagem). Por isso o schema aceita os dois tipos, o nó Validar triagem converte para número e a regra 10 pede o número sem colchetes.
- **Relevância misturada com o foco do cliente:** lançamentos de modelos e notícias sobre custo de manutenção foram descartados com o motivo "sem relação com o foco do cliente". Correção: a regra 2 separa as duas coisas. A relevância vem do tema, e a distância do cliente vai para a aderência.
- **Conteúdo publicitário passando:** títulos de ofertas com preço ("SUVs a partir de R$...") foram marcados como relevantes. Correção: a regra 3 dá exemplos de títulos de anúncio.
- **Resumo apagando números:** na segunda tentativa, o modelo trocou valores do título por "valor específico", aplicando a regra "não acrescente números" além da conta. Correção: a regra 8 deixa claro que os números do título podem ficar.
**Teste 2 (execução completa, 8 lotes, 76 notícias)**

- 76 classificadas, 53 relevantes, nenhuma perdida por erro. Lançamentos entraram com aderência baixa, rankings de vendas com aderência média, dados de financiamento e de usados com aderência alta, e anúncios ("feirão", "a partir de R$") ficaram de fora.
- **Notícias do exterior:** o Google News em português também traz notícias de Portugal e de outros países, e algumas saíram com aderência alta. Correção: a regra 11 limita a aderência de notícias de fora do Brasil a "baixa".
- **Limitação aceita, inconsistência entre lotes:** a mesma notícia, publicada por veículos diferentes e caindo em lotes diferentes, às vezes recebeu classificações diferentes (por exemplo, o mesmo anúncio de crédito para motoristas de aplicativo saiu relevante em 6 lotes e não relevante em 2). Cada lote é uma chamada independente ao modelo. O Redator, na Fase 3, agrupa a mesma notícia e reduz o efeito disso no relatório.
- **Limitação aceita:** sem uma lista de concorrentes, o modelo não sabe quando uma notícia favorece outra empresa do setor, e o tom dessas notícias tende a sair "positivo". A lista não foi incluída de propósito, para não expor o cliente real.
